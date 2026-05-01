require "test_helper"

class ServiciosExtraControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @servicio = ServicioExtra.create!(codigo: "TEST_SETUP", descripcion: "Setup",
                                       costo: 0, precio_venta: 5, moneda: "USD")
  end

  test "index 200 admin" do
    get servicios_extra_url
    assert_response :success
  end

  test "non-admin redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get servicios_extra_url
    assert_redirected_to root_path
  end

  test "create válido" do
    assert_difference "ServicioExtra.count", 1 do
      post servicios_extra_url,
           params: { servicio_extra: { codigo: "NUEVO_TEST", descripcion: "x",
                                       costo: 5, precio_venta: 10, moneda: "USD", activo: true } }
    end
    assert_redirected_to servicios_extra_url
  end

  test "create rechaza codigo inválido" do
    assert_no_difference "ServicioExtra.count" do
      post servicios_extra_url,
           params: { servicio_extra: { codigo: "con espacios", descripcion: "x",
                                       costo: 0, precio_venta: 1, moneda: "USD" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit 200" do
    get edit_servicio_extra_url(@servicio)
    assert_response :success
  end

  test "update cambia precio_venta" do
    patch servicio_extra_url(@servicio),
          params: { servicio_extra: { codigo: @servicio.codigo, descripcion: @servicio.descripcion,
                                      costo: 0, precio_venta: 99, moneda: "USD" } }
    assert_redirected_to servicios_extra_url
    @servicio.reload
    assert_equal 99, @servicio.precio_venta
  end
end
