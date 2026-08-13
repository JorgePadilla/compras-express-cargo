require "test_helper"

# El redondeo a media libra **es la regla**, no algo que alguien prende.
#
# Este archivo probaba el interruptor de `PR-C6.20`: un botón por servicio que
# ponía `incremento_libras` en todas sus filas. El interruptor se fue.
#
# Jorge, mirando la pantalla: *"esta parte me confunde: peso exacto / cobrar en
# medias libras"*, y cerrando la discusión: **"siempre tuvo que estar los
# redondeos, no era de prender, era de que siempre tuvo que estar ahí."**
#
# Y Yusef ya lo había ordenado el 2026-08-09 —`RP-03` "Préndanlo ya", `RP-04`
# "Todo"— pero nadie apretó el botón y las 44 tarifas se quedaron cobrando el
# peso exacto de la báscula durante días.
#
# Lo que hay que fijar ahora no es que el botón prenda: es que **no exista forma
# de que una tarifa quede sin redondeo**.
class ServiciosRedondeoTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
  end

  test "una tarifa nueva nace cobrando en medias libras" do
    assert_equal BigDecimal("0.5"), Tarifa.new.incremento_libras,
                 "una tarifa nueva tiene que redondear sin que nadie la configure"
  end

  test "no se puede guardar una tarifa sin redondeo" do
    t = Tarifa.new(tipo_envio: @cer, desde_libras: 0, precio_libra: 4.50,
                   moneda: "USD", incremento_libras: nil)

    assert_raises(ActiveRecord::NotNullViolation) { t.save!(validate: false) }
  end

  test "ninguna tarifa cargada quedo sin redondeo" do
    assert_equal 0, Tarifa.where(incremento_libras: nil).count
  end

  # El formulario ya no ofrece elegirlo. "Peso exacto" contradecía la regla, y
  # "libra entera" tiene una pregunta abierta: la tolerancia de 0.09 se dictó
  # solo para media libra.
  test "el formulario no deja elegir el incremento" do
    get new_servicio_url(tipo_envio_id: @cer.id)

    assert_response :success
    assert_no_match(/name="tarifa\[incremento_libras\]"/, response.body)
    assert_no_match(/Peso exacto/i, response.body)
  end

  test "el formulario ignora un incremento mandado a mano" do
    # Sin esto, un POST armado a mano podría dejar una tarifa sin redondear.
    post servicios_url, params: {
      tarifa: { tipo_envio_id: @cer.id, desde_libras: 0, precio_libra: 4.50,
                moneda: "USD", incremento_libras: "" }
    }

    assert_equal BigDecimal("0.5"), Tarifa.order(:id).last.incremento_libras
  end

  test "el listado enuncia la regla en vez de ofrecerla" do
    get servicios_url

    assert_response :success
    assert_match(/medias libras/i, response.body)
    assert_no_match(/Cobrar en medias libras/, response.body,
                    "volvió el botón: el redondeo no es una opción")
    assert_no_match(/Volver al peso exacto/, response.body)
  end
end
