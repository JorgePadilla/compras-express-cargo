require "test_helper"
require_relative "../support/con_app_host"

# La pantalla de datos de prueba. Jorge, 2026-10-13: *"this should only be
# available on local and staging"* · *"it should not be visible on production"*.
class DatosDePruebaControllerTest < ActionDispatch::IntegrationTest
  include ConAppHost

  setup do
    ingresar(users(:admin))
    @cer = tipo_envios(:cer)
    @tgu = sucursales(:humuya_tgu)
  end

  # ── Dónde existe ─────────────────────────────────────────────────────────

  test "en producción no hay pantalla, ni link en la barra, ni tarjeta en el Home" do
    en_produccion do
      get "/datos-de-prueba"
      assert_response :not_found

      assert_no_difference -> { PreAlerta.count } do
        post "/datos-de-prueba/pre-alertas", params: { tipo_envio_id: @cer.id, sucursal_id: @tgu.id, cantidad: 2, recibir: "1" }
      end
      assert_response :not_found

      get root_path
      assert_response :success
      assert_no_match "Datos de prueba", response.body
      assert_no_match "/datos-de-prueba", response.body
    end
  end

  test "en staging está, con su link y su tarjeta" do
    en_staging do
      get root_path
      assert_select "a[href='#{datos_de_prueba_path}']", minimum: 2 # la barra y el Home

      get datos_de_prueba_path
      assert_response :success
    end
  end

  test "en local está" do
    get datos_de_prueba_path
    assert_response :success
    assert_select "h1", text: "Datos de prueba"
  end

  test "solo admin" do
    ingresar(users(:supervisor_miami))
    get datos_de_prueba_path
    assert_redirected_to root_path
  end

  # ── Lo que crea ──────────────────────────────────────────────────────────

  test "crea las pre-alertas recibidas en Miami y las lista para escanear" do
    assert_difference -> { PreAlerta.count } => 3 do
      post pre_alertas_datos_de_prueba_path,
           params: { tipo_envio_id: @cer.id, sucursal_id: @tgu.id, cantidad: 3, volumenes: 1, recibir: "1" }
    end
    assert_redirected_to datos_de_prueba_path

    paquetes = DatosDePrueba.paquetes.to_a
    assert_equal 3, paquetes.size
    assert paquetes.all?(&:recibido_miami?)

    follow_redirect!
    assert_match "3 pre-alerta(s) y 3 caja(s)", response.body
    paquetes.each { |p| assert_select "#datos-de-prueba-sueltos td", text: p.numero_recepcion }
  end

  test "con el código de un cliente, van a su nombre; con uno que no existe, avisa" do
    juan = clientes(:juan)
    post pre_alertas_datos_de_prueba_path,
         params: { tipo_envio_id: @cer.id, sucursal_id: @tgu.id, cantidad: 1, recibir: "1", cliente_codigo: juan.codigo.downcase }
    assert_equal juan, DatosDePrueba.paquetes.sole.cliente

    assert_no_difference -> { PreAlerta.count } do
      post pre_alertas_datos_de_prueba_path,
           params: { tipo_envio_id: @cer.id, sucursal_id: @tgu.id, cantidad: 1, recibir: "1", cliente_codigo: "NO-EXISTE" }
    end
    assert_equal "No hay ningún cliente con el código NO-EXISTE.", flash[:alert]
  end

  test "el manifiesto se crea y lleva a su ficha" do
    assert_difference -> { Manifiesto.count } => 1 do
      post manifiesto_datos_de_prueba_path,
           params: { tipo_envio_ids: [ @cer.id ], sucursal_entrega_ids: [ @tgu.id ], cajas: 2, llenar: "0" }
    end
    manifiesto = Manifiesto.order(:id).last
    assert_redirected_to manifiesto_path(manifiesto)
    assert_equal 2, manifiesto.cajas.count
  end

  test "un manifiesto sin tipo de envío no se crea, y dice por qué" do
    assert_no_difference -> { Manifiesto.count } do
      post manifiesto_datos_de_prueba_path, params: { sucursal_entrega_ids: [ @tgu.id ], cajas: 1 }
    end
    assert_redirected_to datos_de_prueba_path
    assert flash[:alert].present?
  end

  private

  def ingresar(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
