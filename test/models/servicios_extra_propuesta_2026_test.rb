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

    assert_operator ServiciosExtraPropuesta2026::PENDIENTES.size, :>=, 9,
                    "los que quedan afuera tienen que seguir listados con su motivo"

    assert_not_includes ServiciosExtraPropuesta2026::PENDIENTES.keys, "CAMBIO DE SERVICIO",
                        "dejo de estar pendiente: Yusef dio el numero en el audio del 2026-08-08"
  end

  # ── Cambio de servicio ──────────────────────────────────────────────────
  #
  # Yusef, 2026-08-08: "son los **100 lempiras**. Yo te lo puse que eran 5."
  # Estaba en $15 USD (~L.373 con ISV): 3.7× de más, en un cargo que se
  # auto-genera en nota de débito al facturar.
  #
  # El test viejo acá no probaba nada: hacía `next if original.nil?` y en el
  # entorno de test no hay fixture de CAMBIO_SERVICIO, así que salía sin una
  # sola aserción. La suite lo venía marcando como "Test is missing assertions".

  test "corrige el cambio de servicio que ya estaba cargado mal" do
    ServicioExtra.create!(
      codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio",
      costo: 0, precio_venta: 15.00, moneda: "USD", precio_incluye_isv: true, activo: true
    )

    resultado = ServiciosExtraPropuesta2026.corregir_cambio_servicio!

    s = ServicioExtra.find_by!(codigo: "CAMBIO_SERVICIO")
    assert resultado[:corregido]
    assert_equal BigDecimal("100"), s.precio_venta
    assert_equal "LPS", s.moneda
    assert s.precio_incluye_isv, "los 100 son el precio final, no el neto"
  end

  test "los L.100 le llegan al cliente como L.100 exactos" do
    # La razón de que vaya con el ISV adentro. El neto es lo que entra a la
    # línea; el ISV se suma una sola vez al totalizar.
    ServicioExtra.create!(
      codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio",
      costo: 0, precio_venta: 15.00, moneda: "USD", precio_incluye_isv: true, activo: true
    )
    ServiciosExtraPropuesta2026.corregir_cambio_servicio!

    s = ServicioExtra.find_by!(codigo: "CAMBIO_SERVICIO")
    neto = s.precio_venta_sin_isv

    assert_equal BigDecimal("86.96"), neto
    assert_equal BigDecimal("100.00"),
                 (neto * (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  test "sembrar tambien lo corrige, para no depender de dos comandos" do
    ServicioExtra.create!(
      codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio",
      costo: 0, precio_venta: 15.00, moneda: "USD", precio_incluye_isv: true, activo: true
    )

    ServiciosExtraPropuesta2026.sembrar!

    assert_equal BigDecimal("100"), ServicioExtra.find_by!(codigo: "CAMBIO_SERVICIO").precio_venta
  end

  test "correr la correccion dos veces no cambia nada la segunda" do
    ServicioExtra.create!(
      codigo: "CAMBIO_SERVICIO", descripcion: "Cambio de servicio",
      costo: 0, precio_venta: 15.00, moneda: "USD", precio_incluye_isv: true, activo: true
    )

    assert ServiciosExtraPropuesta2026.corregir_cambio_servicio![:corregido]
    assert_not ServiciosExtraPropuesta2026.corregir_cambio_servicio![:corregido]
  end

  test "si el cargo no existe la correccion no revienta" do
    assert_not ServiciosExtraPropuesta2026.corregir_cambio_servicio![:corregido]
  end

  test "resembrar no duplica" do
    antes = ServicioExtra.count

    resultado = ServiciosExtraPropuesta2026.sembrar!

    assert_equal antes, ServicioExtra.count
    assert_equal 0, resultado[:creados]
    assert_equal 0, resultado[:actualizados]
  end
end
