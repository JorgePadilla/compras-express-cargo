require "test_helper"

# C30-09 · Recibir varios manifiestos a la vez, sin elegir cuál.
#
#   > **Yusef:** "A veces vamos a recibir tres manifiestos de un solo y hay que
#   >  estar seleccionando cada manifiesto, entonces solo crear un search…"
#   > "Hemos recibido manifiestos hasta cinco de un solo."
#   > "Algo que te vaya diciendo cuál quedó pendiente… si 7 cajas iban 6 nada
#   >  más, falta una."
#
# Dos piezas: `RecibirManifiesto.ubicar`, que dice de qué manifiesto es una
# etiqueta, y `ProgresoDeRecepcion`, que dice cuánto va y qué falta.
class RecepcionVariosManifiestosTest < ActiveSupport::TestCase
  setup do
    @uno = enviado("MRVM000001")
    @dos = enviado("MRVM000002")
    @a1 = @uno.cajas.create!(peso: 10)
    @b1 = @uno.cajas.create!(peso: 10)
    @a2 = @dos.cajas.create!(peso: 10)
  end

  def enviado(numero, **extra)
    Manifiesto.create!({ numero: numero, estado: "enviado", tipo_envio: "AEREO", fecha_enviado: 1.day.ago,
                         sucursal_origen: sucursales(:miami), user: users(:admin),
                         tipo_envios: [ tipo_envios(:cer) ] }.merge(extra))
  end

  def paquete(manifiesto, estado: "enviado_honduras", **extra)
    Paquete.create!({ tracking: "1ZRVM#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan),
                      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                      estado: estado, descripcion: "Ropa", manifiesto: manifiesto }.merge(extra))
  end

  # ── ubicar ──────────────────────────────────────────────────────────────

  test "la etiqueta de una caja dice sola de qué manifiesto es" do
    assert_equal [ :caja, @uno, @b1 ], ubicar(@b1.codigo)
    assert_equal [ :caja, @dos, @a2 ], ubicar(@a2.codigo)
  end

  test "sin importar mayúsculas ni espacios de la pistola" do
    assert_equal [ :caja, @dos, @a2 ], ubicar("  #{@a2.codigo.downcase} ")
  end

  test "una caja de un manifiesto ya cerrado no es pendiente" do
    @uno.update!(estado: "recibido")

    assert_equal :no_pendiente, RecibirManifiesto.ubicar(@a1.codigo).motivo
  end

  test "una caja de un manifiesto que Miami no finalizó no es pendiente" do
    creado = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ])
    caja = creado.cajas.create!(peso: 3)

    assert_equal :no_pendiente, RecibirManifiesto.ubicar(caja.codigo).motivo
  end

  test "un código que no es nada no cae en ningún manifiesto" do
    assert_equal :ninguno, RecibirManifiesto.ubicar("NOEXISTE-Z").motivo
    assert_equal :ninguno, RecibirManifiesto.ubicar("").motivo
  end

  # La búsqueda de paquetes es **estricta**. `Paquete.buscar` hace ILIKE sobre
  # el número del manifiesto, así que escanear la hoja del manifiesto «recibía»
  # su primer paquete; y acá una lectura mala recibe carga.
  test "el número del manifiesto no recibe un paquete cualquiera" do
    paquete(@uno)

    assert_equal :ninguno, RecibirManifiesto.ubicar(@uno.numero).motivo
  end

  test "un paquete suelto de un oficial se reconoce, pero no es lo que se escanea" do
    suelto = paquete(@uno)

    ubicacion = RecibirManifiesto.ubicar(suelto.tracking)

    assert_equal :paquete_de_oficial, ubicacion.motivo
    assert_equal @uno, ubicacion.manifiesto
  end

  test "en el interno se escanea el paquete (A7-08)" do
    interno = enviado("MRVM000009", tipo: "interno", sucursal_entrega: sucursales(:humuya_tgu))
    p = paquete(interno, estado: "enviado_sucursal", sucursal_destino: sucursales(:humuya_tgu))

    assert_equal [ :paquete, interno ], RecibirManifiesto.ubicar(p.tracking).to_h.values_at(:motivo, :manifiesto)
  end

  # ── ProgresoDeRecepcion ─────────────────────────────────────────────────

  test "«6 de 7 · falta 1»: cuántas y cuáles, por letra" do
    RecibirManifiesto.new(@uno).recibir_caja!(@a1)

    progreso = ProgresoDeRecepcion.new(@uno.reload)

    assert_equal "1 de 2 · falta 1", progreso.texto
    assert_equal [ "B" ], progreso.faltantes
    assert_not progreso.completo?
  end

  test "completo cuando llegaron todas" do
    servicio = RecibirManifiesto.new(@uno)
    servicio.recibir_caja!(@a1)
    servicio.recibir_caja!(@b1)

    progreso = ProgresoDeRecepcion.new(@uno.reload)

    assert progreso.completo?
    assert_equal "2 de 2 · completo", progreso.texto
    assert_empty progreso.faltantes
  end

  # C21-01 · El camino sin escaneo: sin cajas no puede decir «0 de 0».
  test "un manifiesto sin cajas dice cuántos paquetes pasan al terminar" do
    sin_cajas = enviado("MRVM000003")
    paquete(sin_cajas)
    paquete(sin_cajas)

    progreso = ProgresoDeRecepcion.new(sin_cajas)

    assert_equal "sin cajas · 2 paquetes pasan al terminar", progreso.texto
    assert_not progreso.completo?
  end

  test "en el interno se cuenta en paquetes" do
    interno = enviado("MRVM000008", tipo: "interno", sucursal_entrega: sucursales(:humuya_tgu))
    llegado = paquete(interno, estado: "enviado_sucursal", sucursal_destino: sucursales(:humuya_tgu))
    falta = paquete(interno, estado: "enviado_sucursal", sucursal_destino: sucursales(:humuya_tgu))
    RecibirManifiesto.new(interno).recibir_paquete!(llegado)

    progreso = ProgresoDeRecepcion.new(interno.reload)

    assert_equal "paquetes", progreso.unidad
    assert_equal "1 de 2 · falta 1", progreso.texto
    assert_equal [ falta.tracking ], progreso.faltantes
  end

  private

  def ubicar(codigo)
    u = RecibirManifiesto.ubicar(codigo)
    [ u.motivo, u.manifiesto, u.caja ]
  end
end
