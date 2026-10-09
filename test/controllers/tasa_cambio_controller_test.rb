require "test_helper"

# PR-C6.29: la pantalla para cambiar la tasa de cambio.
#
# La tasa multiplica **todo** lo que se factura en dólares. Hasta ahora vivía
# solo en `db/seeds.rb` y en la consola: cero rutas y cero vistas la tocaban,
# así que cambiarla requería un deploy.
#
# Yusef, 2026-08-02: "la tasa es **FIJA**, la fija un admin — no se jala del
# día". Por eso es un CRUD y no se reactiva `ActualizarTasaCambioJob`.
#
# Salió a la luz con sus respuestas del 2026-08-09: hizo la cuenta del mínimo
# de CER con **27.10** y el sistema tenía **24.85**.
class TasaCambioControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    ingresar(@admin)
  end

  test "el admin ve la tasa vigente" do
    Configuracion.set("tasa_cambio", "27.10", tipo: "decimal", categoria: "moneda")

    get tasa_cambio_url

    assert_response :success
    assert_match "27.10", response.body
  end

  test "el admin puede cambiarla" do
    patch tasa_cambio_url, params: { tasa_cambio: "28.50" }

    assert_redirected_to tasa_cambio_path
    assert_equal BigDecimal("28.50"), CurrencyAware.tasa_vigente
  end

  test "acepta la coma como separador decimal" do
    # El teclado numérico de Honduras manda coma; escribirla no puede terminar
    # en una tasa de 27 pelado.
    patch tasa_cambio_url, params: { tasa_cambio: "27,10" }

    assert_equal BigDecimal("27.10"), CurrencyAware.tasa_vigente
  end

  test "no acepta cero" do
    patch tasa_cambio_url, params: { tasa_cambio: "0" }

    assert_redirected_to tasa_cambio_path
    assert_not_equal BigDecimal("0"), CurrencyAware.tasa_vigente
  end

  test "no acepta texto" do
    antes = CurrencyAware.tasa_vigente

    patch tasa_cambio_url, params: { tasa_cambio: "veintisiete" }

    assert_equal antes, CurrencyAware.tasa_vigente
  end

  test "no acepta negativos" do
    antes = CurrencyAware.tasa_vigente

    patch tasa_cambio_url, params: { tasa_cambio: "-27.10" }

    assert_equal antes, CurrencyAware.tasa_vigente
  end

  test "el cambio queda registrado en el audit log" do
    # Es plata: tiene que poder rastrearse.
    #
    # Ojo con lo que este test NO afirma: el **quién**. Escribiéndolo salió que
    # `whodunnit` viene nil en TODO el sistema, no solo acá — la guarda
    # `respond_to?(:set_paper_trail_whodunnit)` de `ApplicationController` da
    # false porque el método es privado, así que nunca corre. Va aparte en
    # PR-C6.30, con su propio test; acá se afirma solo lo que hoy es cierto.
    assert_difference -> { PaperTrail::Version.where(item_type: "Configuracion").count }, 1 do
      patch tasa_cambio_url, params: { tasa_cambio: "29.00" }
    end

    version = PaperTrail::Version.where(item_type: "Configuracion").order(:created_at).last
    assert_equal "29.0", version.changeset["valor"].last
  end

  test "un no-admin no entra" do
    ingresar(users(:cajero))

    get tasa_cambio_url

    assert_redirected_to root_path
  end

  test "un no-admin tampoco puede cambiarla" do
    ingresar(users(:cajero))
    antes = CurrencyAware.tasa_vigente

    patch tasa_cambio_url, params: { tasa_cambio: "99.00" }

    assert_redirected_to root_path
    assert_equal antes, CurrencyAware.tasa_vigente
  end

  test "el ejemplo de cobro reproduce la cuenta que hizo Yusef" do
    # Su aritmética sobre el PDF, con la tarifa real de CER:
    #
    #     tasa 27.10 · 4.50 × 1.5 = 182.93 + ISV = 210.36
    #
    # (el motor da 210.37 — él aplicó el ISV sobre 182.925 sin redondear).
    tarifa_cer(precio: 4.50, minimo_neto: 173.91)
    Configuracion.set("tasa_cambio", "27.10", tipo: "decimal", categoria: "moneda")

    get tasa_cambio_url

    assert_match(/210\.3[67]/, response.body,
                 "el ejemplo no reproduce la cuenta que Yusef hizo a mano")
  end

  test "con la tasa vieja el mismo paquete caia en el minimo" do
    # Por qué la tasa importaba: a 24.85 son 6.75 × 24.85 = L.167.76, debajo
    # del mínimo neto de 173.91, así que el paquete cobraba L.200 parejo — y
    # los números de Yusef no reproducían.
    tarifa_cer(precio: 4.50, minimo_neto: 173.91)
    Configuracion.set("tasa_cambio", "24.85", tipo: "decimal", categoria: "moneda")

    get tasa_cambio_url

    assert_match(/200\.00/, response.body)
    assert_match(/minimo/i, response.body)
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # Las fixtures no traen tarifas, así que el escalón de CER se arma acá con
  # los números reales de la hoja de Yusef.
  def tarifa_cer(precio:, minimo_neto:)
    Tarifa.create!(
      tipo_envio: tipo_envios(:cer), desde_libras: 0, hasta_libras: 50.5,
      precio_libra: precio, moneda: "USD", activo: true,
      aplica_minimo: true, minimo_monto: minimo_neto, minimo_moneda: "LPS"
    )
  end
end
