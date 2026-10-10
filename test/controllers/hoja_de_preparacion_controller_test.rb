require "test_helper"

# PR-P.4 · La hoja de preparación, por el controller: permisos, la sesión y lo
# que dibuja cada bloque.
class HojaDePreparacionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @paquete = paquetes(:recibido)
    @paquete.update_columns(manifiesto_id: @manifiesto.id, tipo_envio_id: @cer.id, estado: "en_aduana",
                            pre_factura_id: nil, venta_id: nil)
    Configuracion.where(clave: "prefactura_hora_disponible").delete_all
  end

  # ── Quién entra ─────────────────────────────────────────────────────────

  test "la gente de pre-factura entra" do
    ingresar(users(:supervisor_prefactura))
    get hoja_de_preparacion_url
    assert_response :success
  end

  test "Miami no" do
    ingresar(users(:digitador))
    get hoja_de_preparacion_url
    assert_redirected_to root_path

    patch hoja_de_preparacion_url, params: { hoja: { modo: "nuevas" } }
    assert_redirected_to root_path
  end

  # ── La sesión ───────────────────────────────────────────────────────────

  test "lo elegido queda en la sesión y vuelve dibujado" do
    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: {
      modo: "nuevas", tipo_envio_ids: [ "", @cer.id ], manifiesto_ids: [ "", @manifiesto.id ],
      fecha: "2026-10-12", hora: "14:05"
    } }
    assert_redirected_to hoja_de_preparacion_url

    assert_equal [ @cer.id ], session[:pf_hoja]["tipo_envio_ids"]
    assert_equal [ @manifiesto.id ], session[:pf_hoja]["manifiesto_ids"]
    assert_equal Time.zone.local(2026, 10, 12, 14, 5).iso8601, session[:pf_hoja]["disponible_en"]

    get hoja_de_preparacion_url
    assert_select "#hoja_tipo_envio_#{@cer.id}[checked]"
    assert_select "#hoja_manifiesto_#{@manifiesto.id}[checked]"
    assert_select "#hoja_hora[value=?]", "14:05"
    assert_select "#hoja_fecha[value=?]", "2026-10-12"
  end

  test "sin hoja, la hora es la de por defecto, 07:30, de hoy" do
    ingresar(users(:supervisor_prefactura))
    get hoja_de_preparacion_url

    assert_select "#hoja_hora[value=?]", "07:30"
    assert_select "#hoja_fecha[value=?]", Date.current.iso8601
    assert_select "[data-canales]", text: /Correo \(siempre\).*WhatsApp\/SMS: pendiente de proveedor/
  end

  test "los segundos que llegan se tiran" do
    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { fecha: "2026-10-12", hora: "09:41:27" } }

    assert_equal Time.zone.local(2026, 10, 12, 9, 41, 0).iso8601, session[:pf_hoja]["disponible_en"]
  end

  test "destildar todos los servicios los borra de la sesión" do
    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ "", @cer.id ] } }
    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ "" ] } }

    assert_equal [], session[:pf_hoja]["tipo_envio_ids"]
  end

  test "un manifiesto que ya no se ofrece no queda elegido" do
    ingresar(users(:supervisor_prefactura))
    @paquete.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)   # ya no le queda nada

    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ] } }

    assert_equal [], session[:pf_hoja]["manifiesto_ids"]
  end

  test "«Cerrar la hoja» la borra de la sesión" do
    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ @cer.id ] } }
    assert session[:pf_hoja].present?

    delete hoja_de_preparacion_url
    assert_redirected_to hoja_de_preparacion_url
    assert_nil session[:pf_hoja]
  end

  # ── Lo que dibuja ───────────────────────────────────────────────────────

  test "la tarjeta del manifiesto: número, servicios, cuántos van pre-facturados y las cajas que faltan" do
    otro = paquetes(:empacado)
    otro.update_columns(manifiesto_id: @manifiesto.id, tipo_envio_id: @cer.id, estado: "en_aduana",
                        pre_factura_id: pre_facturas(:borrador_juan).id)
    @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 3, user: users(:supervisor_miami))

    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ @cer.id ] } }
    get hoja_de_preparacion_url

    assert_select "[data-manifiesto=?]", @manifiesto.numero do
      assert_select "*", text: /CER/
      assert_select "*", text: /1 de 2 paquetes pre-facturados/
      assert_select "*", text: /falta 1 caja\b/
    end
  end

  test "el interno no aparece aunque tenga carga" do
    @manifiesto.update_columns(tipo: "interno")
    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ @cer.id ] } }
    get hoja_de_preparacion_url

    assert_select "[data-manifiesto]", count: 0
  end

  test "«Empezar a auditar» lleva a auditar cuando la hoja está lista, y si no, dice qué falta" do
    ingresar(users(:supervisor_prefactura))
    get hoja_de_preparacion_url
    assert_select "button[disabled]", text: /Empezar a auditar/

    patch hoja_de_preparacion_url, params: { hoja: { tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ] } }
    get hoja_de_preparacion_url
    assert_select "a[href=?]", auditar_pre_factura_index_path, text: /Empezar a auditar/
  end

  test "«editar» lista las pre-facturas sin avisar de cada manifiesto, con su link" do
    pf = pre_facturas(:borrador_juan)
    pf.update_columns(manifiesto_id: @manifiesto.id, estado: "creado")

    ingresar(users(:supervisor_prefactura))
    patch hoja_de_preparacion_url, params: { hoja: { modo: "editar" } }
    get hoja_de_preparacion_url

    assert_select "[data-manifiesto=?] a[href=?]", @manifiesto.numero, edit_pre_factura_path(pf)
    assert_select "[data-paso='3']", count: 0, message: "cambiar la hora en lote es PR-P.7"
  end

  test "el link está en Logística y la tarjeta en el Home" do
    ingresar(users(:supervisor_prefactura))
    get root_url
    assert_select "a[href=?]", hoja_de_preparacion_path, minimum: 1
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
