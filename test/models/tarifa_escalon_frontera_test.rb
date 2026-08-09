require "test_helper"

# PR-C6.18: el escalón se elige con el peso que se va a COBRAR.
#
# El bug salió planeando la activación del escalonado, no de un reporte: hoy
# `Tarifa.para_peso` filtra con el peso **crudo** de la báscula, pero
# `redondear_al_incremento` corre después, adentro de `cobro_para`. O sea que
# el escalón se elige con un peso y el precio se aplica a otro.
#
# Un CER de 50.2 lb caía en el tramo `[0, 50.5)` a $4.50, redondeaba a 50.5 y
# cobraba 50.5 × 4.50 = **$227.25**. La hoja de Yusef dice que 50.5 lb van en
# el tramo de $4.00, o sea **$202.00**. **$25.25 de más**, y siempre a favor
# de CEC, porque los tramos de arriba son más baratos por libra.
#
# Pasa en toda la banda `(frontera − 0.41, frontera)`: 50.5 / 100.5 / 150.5 en
# CER, y 3.5 / 13.5 / 100.5 / 200.5 en los marítimos. No es un borde raro.
#
# **Está dormido**: `incremento_libras` viene nil en las 58 tarifas cargadas,
# así que hoy no cobra mal. Se despierta el día que se active el escalonado —
# que es exactamente lo que Yusef acaba de ordenar ("préndanlo ya"). Por eso
# este PR va ANTES del botón de activación.
class TarifaEscalonFronteraTest < ActiveSupport::TestCase
  setup do
    @tipo = tipo_envios(:cer)
    Tarifa.where(tipo_envio: @tipo).destroy_all
    @barato = escalon(desde: 50.5, hasta: nil,  precio: 4.00)
    @caro   = escalon(desde: 0,    hasta: 50.5, precio: 4.50)
  end

  test "el peso que cruza la frontera al redondear cae en el escalon de arriba" do
    tarifa = resolver(50.2)

    assert_equal @barato, tarifa, "eligió el escalón con el peso crudo, no con el facturable"
    assert_equal 202.00, tarifa.cobro_para(50.2)[:subtotal].to_f
  end

  test "el peso facturado es el redondeado" do
    assert_equal 50.5, resolver(50.2).cobro_para(50.2)[:peso_facturado].to_f
  end

  test "el que no cruza se queda donde estaba" do
    # 50.09 − 0.09 = 50.0 exacto: redondea para abajo y no toca la frontera.
    tarifa = resolver(50.09)

    assert_equal @caro, tarifa
    assert_equal 225.00, tarifa.cobro_para(50.09)[:subtotal].to_f   # 50.0 × 4.50
  end

  test "el que ya estaba arriba tampoco se mueve" do
    tarifa = resolver(50.55)

    assert_equal @barato, tarifa
    assert_equal 202.00, tarifa.cobro_para(50.55)[:subtotal].to_f   # redondea a 50.5
  end

  test "sin escalonado activo el camino es identico" do
    # La garantía de que este PR no mueve un centavo hoy: con
    # `incremento_libras` nil, resolver devuelve lo mismo que siempre.
    Tarifa.where(tipo_envio: @tipo).update_all(incremento_libras: nil)

    tarifa = resolver(50.2)

    assert_equal @caro, tarifa
    assert_equal 225.90, tarifa.cobro_para(50.2)[:subtotal].to_f   # 50.2 × 4.50, el peso exacto
  end

  test "el peso facturable no aplica el minimo en libras" do
    # `minimo_libras` es un piso sobre el cobro, no una reclasificación del
    # paquete. Y Yusef lo cerró: "manda el escalonado", sin mínimo en libras.
    @caro.update!(minimo_libras: 8)

    assert_equal 1.0, @caro.peso_facturable(1.05).to_f
  end

  test "la sucursal y el cliente sobreviven a la segunda pasada" do
    # `resolver` re-resuelve con el peso redondeado. Si esa segunda pasada
    # perdiera el contexto, el split CKM San Pedro / Tegucigalpa se caería a la
    # tarifa genérica — y eso es plata.
    tgu = escalon(desde: 50.5, hasta: nil, precio: 3.00, sucursal: sucursales(:humuya_tgu))

    tarifa = resolver(50.2, sucursal: sucursales(:humuya_tgu))

    assert_equal tgu, tarifa
    assert_equal 151.50, tarifa.cobro_para(50.2)[:subtotal].to_f   # 50.5 × 3.00
  end

  test "un peso sin ningun escalon sigue devolviendo nil" do
    Tarifa.where(tipo_envio: @tipo).destroy_all

    assert_nil resolver(10)
  end

  private

  def escalon(desde:, hasta:, precio:, sucursal: nil)
    Tarifa.create!(
      tipo_envio: @tipo, desde_libras: desde, hasta_libras: hasta,
      precio_libra: precio, moneda: "USD", incremento_libras: 0.5,
      sucursal: sucursal, activo: true, aplica_minimo: false
    )
  end

  def resolver(peso, **extra)
    Tarifa.resolver(tipo_envio: @tipo, peso: peso, **extra)
  end
end
