require "test_helper"

# C26-19 · El bulto: una medición, una etiqueta, muchas cajas.
#
# Yusef, el 2026-09-07: *"no es una etiqueta por paquete, es una etiqueta por
# medición, y la medición puede tener 100 paquetes"*. Y desde C28-08 las cajas
# son de la **tanda**: se escanean todas y después salen los volúmenes.
class MedirBultoTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @user.update!(iniciales: "SP")
    @cliente = clientes(:juan)
    @otro = clientes(:maria)
  end

  # 10×12×14 = 1680 in³ ÷ 166 = 10.12 → .10/.60 → 10.5; manda el peso real.
  test "tres cajas en un volumen se cobran UNA vez, no tres" do
    cajas = 3.times.map { caja }

    bultos = medir(cajas, { peso: "20", alto: "10", largo: "12", ancho: "14" })

    assert_equal 1, bultos.size
    bulto = bultos.first
    assert_equal 20.0, bulto.peso.to_f
    assert_equal 10.5, bulto.peso_volumetrico.to_f
    assert_equal 20.0, bulto.peso_cobrar.to_f, "el bulto cobra sus 20 libras, una sola vez"
    assert_equal cajas.map(&:id).sort, bulto.paquetes.pluck(:id).sort
  end

  # La trampa que este diseño existe para evitar: si el peso del bulto se
  # copiara a cada caja, `calculate_peso_cobrar` cobraría 20 tres veces.
  test "a las cajas no se les toca el peso: siguen con el dato de Miami" do
    cajas = 3.times.map { |i| caja(peso: 3 + i, alto: 5, largo: 6, ancho: 7) }

    medir(cajas, { peso: "20", alto: "10", largo: "12", ancho: "14" })

    pesos = cajas.map { |c| c.reload.peso.to_f }
    assert_equal [ 3.0, 4.0, 5.0 ], pesos, "el peso de Miami se pisó con el del bulto"
    assert_equal [ [ 5.0, 6.0, 7.0 ] ] * 3, cajas.map { |c| [ c.alto.to_f, c.largo.to_f, c.ancho.to_f ] }
    assert_equal [ 20.0 ], cajas.flat_map { |c| c.bultos.map { |b| b.peso_cobrar.to_f } }.uniq,
                 "un solo bulto, un solo cobro"
  end

  test "cada caja queda sellada con quién midió, cuándo, y en qué tanda" do
    cajas = 2.times.map { caja }

    bulto = medir(cajas, { peso: "12", alto: "10", largo: "12", ancho: "14" }).first

    cajas.each do |c|
      c.reload
      assert_equal "SP", c.medido_por
      assert_not_nil c.medido_at
      assert_equal bulto.sesion, c.medicion_sesion
    end
  end

  # ── C28-08 · Escanear todo, y después los volúmenes ──────────────────────
  #
  # *"La medición la va a decidir después de haber escaneado… para ellos es
  # mejor solo escanear, que sí están ahí, y ellos lo acomodan como gustan para
  # medir y pesar."*

  test "C28-08 · siete cajas y tres volúmenes: ningún volumen tiene cajas propias" do
    cajas = 7.times.map { caja }

    bultos = medir(cajas, { peso: "4", alto: "10", largo: "2", ancho: "10" },
                          { peso: "3", alto: "8", largo: "8", ancho: "12" },
                          { peso: "2" })

    assert_equal [ "1 de 3", "2 de 3", "3 de 3" ], bultos.map(&:de_cuantos_texto)
    assert_equal 1, bultos.map(&:sesion).uniq.size, "una sola tanda"
    assert_equal [ bultos.first.sesion ], cajas.map { |c| c.reload.medicion_sesion }.uniq
    bultos.each { |b| assert_equal cajas.map(&:id).sort, b.paquetes.pluck(:id).sort, "cada volumen ve la tanda entera" }
  end

  test "C28-08 · un solo volumen no dice «1 de 1»" do
    bulto = medir([ caja ], { peso: "10" }).first

    assert bulto.unico?
    assert_nil bulto.de_cuantos_texto
  end

  test "C28-08 · sin cajas no hay tanda" do
    e = assert_raises(MedirBulto::NoSePuede) do
      MedirBulto.new(user: @user).guardar!(paquete_ids: [], volumenes: [ { peso: "10" } ])
    end
    assert_match(/ninguna caja/, e.message)
  end

  test "C28-08 · sin volúmenes no hay nada que guardar" do
    e = assert_raises(MedirBulto::NoSePuede) do
      MedirBulto.new(user: @user).guardar!(paquete_ids: [ caja.id ], volumenes: [])
    end
    assert_match(/ningún volumen/, e.message)
  end

  test "C28-08 · la misma caja escaneada dos veces no pasa" do
    una = caja

    e = assert_raises(MedirBulto::NoSePuede) do
      MedirBulto.new(user: @user).guardar!(paquete_ids: [ una.id, una.id ], volumenes: [ { peso: "10" } ])
    end
    assert_match(/escaneada dos veces/, e.message)
  end

  # ── C27-33 · Medir de nuevo, ahora la tanda entera ──────────────────────

  test "medir de nuevo reemplaza todos los volúmenes de la tanda" do
    cajas = 3.times.map { caja }
    viejos = medir(cajas, { peso: "10" }, { peso: "20" })

    nuevos = MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: "25" } ],
                                                  reemplaza_sesion: viejos.first.sesion)

    assert_empty Bulto.where(id: viejos.map(&:id))
    assert_equal [ nuevos.first.sesion ], cajas.map { |c| c.reload.medicion_sesion }.uniq
    assert_equal 25.0, nuevos.first.peso.to_f
  end

  test "la caja que se sacó al medir de nuevo vuelve a estar sin medir" do
    quedan = 2.times.map { caja }
    sale = caja
    viejos = medir(quedan + [ sale ], { peso: "10" })

    MedirBulto.new(user: @user).guardar!(paquete_ids: quedan.map(&:id), volumenes: [ { peso: "8" } ],
                                         reemplaza_sesion: viejos.first.sesion)

    sale.reload
    assert_nil sale.medicion_sesion
    assert_nil sale.medido_at
  end

  test "una caja de otra tanda no entra sin medirla de nuevo" do
    medida = caja
    medir([ medida ], { peso: "10" })

    e = assert_raises(MedirBulto::NoSePuede) { medir([ medida, caja ], { peso: "12" }) }
    assert_match(/ya está medida/, e.message)
  end

  # La regla de C26-18, ahora sobre el bulto.
  test "una cajita con solo el peso hace un bulto" do
    bulto = medir([ caja ], { peso: "2.5", alto: "", largo: "", ancho: "" }).first

    assert_equal 2.5, bulto.peso.to_f
    assert_nil bulto.peso_volumetrico
    assert_equal 2.5, bulto.peso_cobrar.to_f
  end

  test "dos de tres medidas no pasa" do
    e = assert_raises(MedirBulto::NoSePuede) do
      medir([ caja ], { peso: "10", alto: "", largo: "12", ancho: "14" })
    end
    assert_match(/las tres/, e.message)
    assert_equal 0, Bulto.count
  end

  # ── «NO Mezclar» ─────────────────────────────────────────────────────────

  test "dos clientes no se miden juntos" do
    mio = caja
    ajeno = caja(cliente: @otro)

    e = assert_raises(MedirBulto::NoSePuede) do
      medir([ mio, ajeno ], { peso: "10", alto: "10", largo: "10", ancho: "10" })
    end
    assert_match(/No se miden juntos/, e.message)
    assert_equal 0, Bulto.count, "no se guardó nada"
  end

  test "dos servicios no se miden juntos" do
    uno = caja
    otro = caja(tipo_envio: tipo_envios(:cem))

    e = assert_raises(MedirBulto::NoSePuede) do
      medir([ uno, otro ], { peso: "10", alto: "10", largo: "10", ancho: "10" })
    end
    assert_match(/se factura aparte/, e.message)
  end

  # Yusef: *"le debería tirar un error, un modal que le diga: hey, no, ese está
  # consolidando con tal pre-alerta. **Ese va amarrado con otra**"*. El porqué lo
  # confirmó con Vanessa en la misma reunión: consolidado y suelto llevan
  # facturas separadas —*"nosotros facturamos de acuerdo a la pre-alerta"*—.
  #
  # El orden importa —«NO Mezclar» compara contra la **primera** escaneada— y
  # hasta C28-08 `MedirBulto` lo perdía: `where(id:)` devuelve las cajas como
  # se le ocurre a la base, y estos dos tests caían de vez en cuando en CI.
  test "una caja consolidada no entra donde hay sueltas, y el modal dice con cuál va amarrada" do
    suelta = caja(tipo_envio: tipo_envios(:aereo))
    pa = pre_alerta_consolidada("1ZCONS000000001")
    consolidada = llego(pa.pre_alerta_paquetes.first.paquete)

    e = assert_raises(MedirBulto::NoSePuede) { medir([ suelta, consolidada ], { peso: "10" }) }
    assert_match(/está consolidando con la pre-alerta #{pa.numero_documento}/, e.message)
    assert_match(/lo dejás de lado/, e.message)
  end

  # La otra dirección: ya armó el consolidado y le meten una suelta.
  test "una caja suelta no entra donde se está armando un consolidado" do
    pa = pre_alerta_consolidada("1ZCONS000000002")
    consolidada = llego(pa.pre_alerta_paquetes.first.paquete)
    suelta = caja(tipo_envio: tipo_envios(:aereo))

    e = assert_raises(MedirBulto::NoSePuede) { medir([ consolidada, suelta ], { peso: "10" }) }
    assert_match(/no está consolidando/, e.message)
    assert_match(/#{pa.numero_documento}/, e.message)
  end

  test "dos cajas del mismo consolidado sí van en un bulto" do
    pa = pre_alerta_consolidada("1ZCONS000000003", "1ZCONS000000004")
    dos = pa.pre_alerta_paquetes.map { |r| llego(r.paquete) }

    bulto = medir(dos, { peso: "30", alto: "20", largo: "20", ancho: "20" }).first

    assert_equal 2, bulto.paquetes.count
    # 20×20×20 = 8000 in³ ÷ 166 = 48.19 → .10/.60 → 48.5, que le gana a las 30
    # libras reales. Es la misma cadena de siempre, ahora sobre el bulto.
    assert_equal 48.5, bulto.peso_volumetrico.to_f
    assert_equal 48.5, bulto.peso_cobrar.to_f, "cobra el mayor"
  end

  # ── Las guardas de siempre, ahora por caja de la tanda ───────────────────

  test "si una sola caja ya está en pre-factura, no se guarda ninguna" do
    buenas = 2.times.map { caja }
    mala = caja
    mala.update_columns(pre_factura_id: PreFactura.first.id)

    e = assert_raises(MedirBulto::NoSePuede) do
      medir(buenas + [ mala ], { peso: "10", alto: "10", largo: "10", ancho: "10" })
    end
    assert_match(/pre-factura/, e.message)
    assert_equal 0, Bulto.count
    assert_nil buenas.first.reload.medido_at, "las buenas tampoco se sellaron"
  end

  test "una caja que todavía no llegó a Honduras frena la tanda" do
    aca = caja
    en_camino = caja
    en_camino.update_columns(estado: "enviado_honduras")

    e = assert_raises(MedirBulto::NoSePuede) { medir([ aca, en_camino ], { peso: "10" }) }
    assert_match(/Recibir Carga/, e.message)
  end

  # Yusef: *"máximo 10 warehouse, máximo 10 etiquetas"*.
  test "más de diez volúmenes en una tanda no pasan" do
    e = assert_raises(MedirBulto::NoSePuede) { medir([ caja ], *Array.new(11) { { peso: "10" } }) }
    assert_match(/#{Bulto::MAXIMO_POR_SESION}/, e.message)
    assert_equal 0, Bulto.count
  end

  test "diez sí pasan" do
    bultos = medir([ caja ], *Array.new(10) { { peso: "10" } })

    assert_equal 10, bultos.size
    assert_equal 10, bultos.last.de_cuantos
  end

  # ── C27-14 · Saltarse el manifiesto ──────────────────────────────────────

  test "una caja que no pasó por el manifiesto no entra… salvo que alguien ponga su nombre" do
    suelta = caja
    suelta.update_columns(estado: "enviado_honduras")

    assert_raises(MedirBulto::NoSePuede) { medir([ suelta ], { peso: "20" }) }

    MedirBulto.new(user: @user, saltar_manifiesto: [ suelta.id ])
              .guardar!(paquete_ids: [ suelta.id ], volumenes: [ { peso: "20" } ])

    suelta.reload
    assert_not_nil suelta.medicion_sesion
    assert_equal "SP", suelta.salto_manifiesto_por
    assert_equal "enviado_honduras", suelta.salto_manifiesto_estado
  end

  test "el permiso es por caja: la que sí pasó por el manifiesto no queda sellada" do
    buena = caja
    suelta = caja
    suelta.update_columns(estado: "enviado_honduras")

    MedirBulto.new(user: @user, saltar_manifiesto: [ buena.id, suelta.id ])
              .guardar!(paquete_ids: [ buena.id, suelta.id ], volumenes: [ { peso: "20" } ])

    assert_nil buena.reload.salto_manifiesto_at, "no hubo excepción que sellar"
    assert_not_nil suelta.reload.salto_manifiesto_at
  end

  private

  def medir(cajas, *volumenes)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  def pre_alerta_consolidada(*trackings)
    pa = PreAlerta.create!(numero_documento: "PA-B#{SecureRandom.hex(3).upcase}", cliente: @cliente,
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    trackings.each { |t| pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto", fecha: Date.current) }
    pa
  end

  # Miami lo recibe —ahí nace el warehouse receipt— y llega a Honduras.
  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.reload.update!(estado: "en_aduana")
    paquete.reload
  end

  def caja(cliente: @cliente, tipo_envio: tipo_envios(:cer), **extra)
    Paquete.create!(tracking: "1ZBULTO#{SecureRandom.hex(5).upcase}", cliente: cliente,
                    tipo_envio: tipo_envio, sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", **extra)
  end
end
