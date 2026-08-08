require "test_helper"

# PR-C6.6: el código de barras distingue caja 1 de caja 2.
#
# Yusef, 2026-08-08, mirando la etiqueta de un tracking dividido:
#
#   "Si yo escaneo esto no sé si es el paquete uno o el paquete dos."
#   "Aquí sería 7-1, 7-2."
#
# `crear_split!` le asigna a las N cajas **el mismo** `numero_recepcion` (el
# número madre) y las diferencia solo por `numero_caja` — el índice único es
# compuesto. La etiqueta codificaba ese número pelado, así que las dos cajas
# llevaban el MISMO código impreso.
#
# Por qué importa: al recibir en San Pedro se escanea para **rebajar del
# inventario**, y ahí hay que saber cuál llegó y cuál falta.
#
#   "Esa etiqueta selecciona del inventario... el paquete que sí vino, y que
#    falta el otro. De esa manera él rebaja."
class EtiquetaBarcodePorCajaTest < ActionView::TestCase
  include EtiquetaHelper

  setup do
    @cliente = clientes(:juan)
    @miami = sucursales(:miami)
  end

  test "cada caja de un split lleva su propio codigo" do
    cajas = crear_split(2)
    madre = cajas.first.numero_recepcion

    assert_equal "#{madre}-1", etiqueta_codigo_barras(cajas[0])
    assert_equal "#{madre}-2", etiqueta_codigo_barras(cajas[1])
    assert_not_equal etiqueta_codigo_barras(cajas[0]), etiqueta_codigo_barras(cajas[1]),
                     "las dos cajas llevan el mismo código: no se puede rebajar inventario"
  end

  test "un paquete de una sola caja va sin sufijo" do
    p = crear_paquete
    assert_equal p.numero_recepcion, etiqueta_codigo_barras(p)
  end

  test "sin numero de recepcion NO se cae al tracking" do
    # La regla de Yusef: "el código de barra que está aquí es el warehouse, no
    # es el tracking". Sin recepción no se imprime barcode — una etiqueta sin
    # código es un problema visible; una con el código equivocado se escanea
    # mal en San Pedro y nadie se entera.
    p = crear_paquete
    p.update_columns(numero_recepcion: nil, sucursal_recepcion_id: nil)

    assert_nil etiqueta_codigo_barras(p)
  end

  test "el sufijo va en la recepcion, nunca en el tracking" do
    # El error del sistema viejo: "el tracking él le agregaba un 2, y al
    # warehouse él le agregaba un 2 y el 1".
    cajas = crear_split(3)

    assert_equal 1, cajas.map(&:tracking).uniq.size,
                 "el split le tocó el tracking a alguna caja"
    assert cajas.none? { |c| c.tracking.match?(/-\d\z/) },
           "el tracking quedó con sufijo de caja"
  end

  # ── El escaneo en San Pedro ────────────────────────────────────────────

  test "escanear el codigo de una caja cae en esa caja" do
    cajas = crear_split(3)
    madre = cajas.first.numero_recepcion

    resultado = Paquete.buscar("#{madre}-2")

    assert_equal 1, resultado.count, "el escaneo trajo #{resultado.count} paquetes"
    assert_equal cajas[1], resultado.first
    assert_equal 2, resultado.first.numero_caja
  end

  test "escanear el numero madre trae las tres cajas" do
    cajas = crear_split(3)

    assert_equal 3, Paquete.buscar(cajas.first.numero_recepcion).count
  end

  test "un tracking con guiones no se confunde con una caja" do
    # `TBA303384-2` es un tracking de verdad, no la caja 2 de nada. Si el
    # parseo se lo comiera, buscar por tracking dejaría de funcionar.
    p = crear_paquete(tracking: "TBA303384-2")

    resultado = Paquete.buscar("TBA303384-2")

    assert_includes resultado, p
  end

  test "el codigo de una caja que no existe cae a la busqueda normal" do
    p = crear_paquete
    # Con sufijo pero sin caja que matchee: no debe devolver vacío por haber
    # entrado a la rama del escaneo.
    resultado = Paquete.buscar("#{p.numero_recepcion}-9")

    assert_includes resultado, p,
                    "la rama del escaneo se comió la búsqueda normal"
  end

  private

  def crear_paquete(**overrides)
    Paquete.create!({
      tracking: "BC#{SecureRandom.hex(4)}",
      cliente: @cliente,
      sucursal_recepcion: @miami,
      estado: "empacado",
      descripcion: "Paquete de prueba",
      user: users(:digitador)
    }.merge(overrides))
  end

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "SPLIT#{SecureRandom.hex(4)}",
        cliente: @cliente,
        sucursal_recepcion: @miami,
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end
end
