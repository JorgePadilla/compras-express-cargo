require "test_helper"

# El "Valor a pagar" cuando el envío tiene varias cajas — `PR-C7.17`.
#
# Jorge, con dos cajas de 40 lb cargadas: *"el cálculo no está haciendo la suma
# de las 2 cajas tampoco"*. Y era peor que no sumar: el panel cotizaba con los
# campos de captura, que "Agregar caja" vacía, así que el cobro **se desplomaba
# al mínimo de servicio** — L.200 por un envío de 80 lb.
#
# ── Por qué se cotiza caja por caja y no sumando las libras ────────────────
#
# Porque así es como `PreFactura#build_from_paquetes` arma las líneas: una por
# caja, y cada una resuelve su propio escalón y compara contra su propio mínimo.
#
# Sumar las libras y cotizar una sola vez daría un número **más barato que el que
# la factura va a cobrar**, que es exactamente la divergencia que este PR cierra.
# Con las cajas del ejemplo de `A9-03` la diferencia medida es de $14.00.
#
# Si algún día se decide cobrar por envío, se cambia en los dos lados. Está
# abierto como `RP-41`.
class CotizadorPorCajasTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    @cer = tipo_envios(:cer)
    Tarifa.delete_all
  end

  def cotizar(**params)
    get cotizador_url, params: { tipo_envio_id: @cer.id, cliente_id: clientes(:juan).id }.merge(params)
    JSON.parse(response.body)
  end

  test "sin cajas cotiza el bulto de arriba, como siempre" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 1.00, moneda: "USD", aplica_minimo: false)

    d = cotizar(peso: 40)

    assert d["ok"]
    assert_equal 40.0, d["peso_cobrar"]
  end

  # El caso que Jorge reportó, dicho como test.
  test "con dos cajas de 40 lb el peso a cobrar es 80, no 40" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 1.00, moneda: "USD", aplica_minimo: false)

    d = cotizar(cajas: { "1" => { peso: 40 }, "2" => { peso: 40 } })

    assert_equal 80.0, d["peso_cobrar"]
    assert_equal 80.0, d["subtotal"]["usd"]
  end

  # Y el otro lado del bug: con los campos de captura vacíos ya no se desploma.
  test "las cajas mandan aunque los campos de captura vengan vacios" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 1.00, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")

    d = cotizar(peso: "", alto: "", largo: "", ancho: "",
                cajas: { "1" => { peso: 40 }, "2" => { peso: 40 } })

    assert_equal 80.0, d["peso_cobrar"]
    assert_not d["aplico_minimo"], "cotizó el mínimo de servicio con dos cajas cargadas"
  end

  # La regla de A9-03: el mayor de cada caja individualmente, y después se suman.
  # Con una caja pesada y otra voluminosa los dos criterios no coinciden.
  test "toma el mayor de cada caja, no el mayor de las sumas" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 1.00, moneda: "USD", aplica_minimo: false)

    # caja 1: 5 lb real vs 4.5 vol → 5.0 · caja 2: 2 lb real vs 163 vol → 163.0
    d = cotizar(cajas: { "1" => { peso: 5, alto: 10, largo: 5,  ancho: 15 },
                         "2" => { peso: 2, alto: 30, largo: 30, ancho: 30 } })

    assert_equal 168.0, d["peso_cobrar"]
    assert_not_equal 167.5, d["peso_cobrar"],
                     "sumó los reales y los volumétricos por separado y tomó el mayor"
  end

  # Con las cajas en escalones distintos no hay un precio por libra que mostrar.
  test "sin un precio por libra comun lo dice en vez de mentir con el de una caja" do
    Tarifa.create!(tipo_envio: @cer, desde_libras: 0, hasta_libras: 50,
                   precio_libra: 4.50, moneda: "USD", aplica_minimo: false)
    Tarifa.create!(tipo_envio: @cer, desde_libras: 50,
                   precio_libra: 3.50, moneda: "USD", aplica_minimo: false)

    d = cotizar(cajas: { "1" => { peso: 5 }, "2" => { peso: 163 } })

    assert_nil d["precio_libra"]
    # El delta es el round-trip de moneda: se cotiza en lempiras —que es como se
    # factura— y el dólar se devuelve convertido de vuelta, así que pierde
    # centavos. No es imprecisión del cálculo.
    assert_in_delta (5 * 4.50) + (163 * 3.50), d["subtotal"]["usd"], 0.10
  end

  # Lo que hace que el panel no mienta: el mismo envío tiene que dar lo mismo en
  # la pantalla y en la pre-factura.
  test "cotiza lo mismo que la pre-factura para el mismo envio" do
    Tarifa.create!(tipo_envio: @cer, desde_libras: 0, hasta_libras: 50,
                   precio_libra: 4.50, moneda: "USD", aplica_minimo: false)
    Tarifa.create!(tipo_envio: @cer, desde_libras: 50,
                   precio_libra: 3.50, moneda: "USD", aplica_minimo: false)

    pesos = [ 5, 9, 163 ]
    d = cotizar(cajas: pesos.each_with_index.to_h { |p, i| [ (i + 1).to_s, { peso: p } ] })

    como_la_pre_factura = pesos.sum do |p|
      t = Tarifa.resolver(tipo_envio: @cer, peso: p, cliente: clientes(:juan))
      t.cobro_para(p)[:subtotal].to_f
    end

    assert_in_delta como_la_pre_factura, d["subtotal"]["usd"], 0.10
  end
end
