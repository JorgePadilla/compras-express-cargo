require "test_helper"

# PR-10.i: los cargos que no son flete, de la hoja de Yusef.
#
# Solo van los cinco que el propio texto de la hoja define sin dudas. El resto
# necesita que confirme la moneda: la hoja tiene una leyenda de colores
# ("PRECIOS EN $" / "PRECIOS EN LEMPIRAS") que **nunca se aplicó a las celdas**,
# así que el número solo no dice en qué moneda está.
#
# Cargarlos adivinando sería peor que no cargarlos — son montos que se le cobran
# al cliente.
class ServiciosExtraPropuesta2026Test < ActiveSupport::TestCase
  setup { ServiciosExtraPropuesta2026.sembrar! }

  test "carga los cinco cargos sin ambiguedad" do
    %w[ENTREGA_NACIONAL COMPRA_ONLINE MANEJO_DESTINO FLETE_INTL_UPS RETORNADO_MIAMI].each do |codigo|
      assert ServicioExtra.exists?(codigo: codigo), "falta #{codigo}"
    end
  end

  test "la entrega nacional son L.86.96 netos, que con ISV dan L.100 exactos" do
    # De ahí sale la certeza de la moneda: el título de la fila dice "L100" y la
    # aritmética cierra al centavo.
    s = ServicioExtra.find_by!(codigo: "ENTREGA_NACIONAL")

    assert_equal "LPS", s.moneda
    assert_equal BigDecimal("86.96"), s.precio_venta
    assert_not s.precio_incluye_isv, "la hoja dice PRECIOS NO INCLUYEN IMPUESTOS"

    con_isv = (s.precio_venta.to_d * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
    assert_equal BigDecimal("100.00"), con_isv
  end

  test "las monedas salen de la nota escrita en cada fila" do
    assert_equal "USD", ServicioExtra.find_by!(codigo: "COMPRA_ONLINE").moneda    # "ponerlo $1 mas isv"
    assert_equal "LPS", ServicioExtra.find_by!(codigo: "MANEJO_DESTINO").moneda   # "ponerlo lps1 mas isv"
    assert_equal "USD", ServicioExtra.find_by!(codigo: "FLETE_INTL_UPS").moneda   # el titulo dice "$1"
    assert_equal "USD", ServicioExtra.find_by!(codigo: "RETORNADO_MIAMI").moneda  # "todo en $"
  end

  test "ninguno lleva el ISV adentro" do
    # "**PRECIOS NO INCLUYEN IMPUESTOS" es lo único de la leyenda que sí aplica a
    # toda la hoja. Si alguno entrara con el ISV adentro, se cobraría de menos:
    # `precio_venta_sin_isv` le sacaría un 15% que nunca tuvo.
    ServiciosExtraPropuesta2026::CARGOS.each do |c|
      s = ServicioExtra.find_by!(codigo: c[:codigo])
      assert_not s.precio_incluye_isv, "#{c[:codigo]} no debe traer ISV adentro"
      assert_equal s.precio_venta, s.precio_venta_sin_isv
    end
  end

  test "NO carga los que tienen la moneda sin definir" do
    # El guard de todo esto: si alguien agrega un cargo a CARGOS sin poder
    # justificar la moneda, este test lo obliga a documentar por qué.
    ServiciosExtraPropuesta2026::CARGOS.each do |c|
      assert c[:certeza].present?,
             "#{c[:codigo]} entra sin decir de donde sale la certeza de su moneda"
    end

    assert_operator ServiciosExtraPropuesta2026::PENDIENTES.size, :>=, 10,
                    "los que quedan afuera tienen que seguir listados con su motivo"
  end

  test "no pisa el cambio de servicio que ya existe" do
    # Es el que se auto-genera en nota de débito al facturar. La hoja de Yusef
    # dice 5 y el sistema tiene $15 — tocarlo sin confirmar cambiaría lo que se
    # le cobra al cliente en un documento que se emite solo.
    original = ServicioExtra.find_by(codigo: "CAMBIO_SERVICIO")
    next if original.nil?

    ServiciosExtraPropuesta2026.sembrar!

    assert_equal original.precio_venta, original.reload.precio_venta
  end

  test "resembrar no duplica" do
    antes = ServicioExtra.count

    resultado = ServiciosExtraPropuesta2026.sembrar!

    assert_equal antes, ServicioExtra.count
    assert_equal 0, resultado[:creados]
    assert_equal 0, resultado[:actualizados]
  end
end
