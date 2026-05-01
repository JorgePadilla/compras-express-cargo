require "test_helper"

class ProveedoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @proveedor = Proveedor.create!(nombre: "Test Setup Inc", tipo: "comercio")
  end

  test "index 200 para admin" do
    get proveedores_url
    assert_response :success
  end

  test "non-admin queda redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get proveedores_url
    assert_redirected_to root_path
  end

  test "new 200" do
    get new_proveedor_url
    assert_response :success
  end

  test "create válido + auto-codigo" do
    assert_difference "Proveedor.count", 1 do
      post proveedores_url,
           params: { proveedor: { nombre: "Hello Fresh", tipo: "comercio", activo: true } }
    end
    assert_redirected_to proveedores_url
    nuevo = Proveedor.find_by(nombre: "Hello Fresh")
    assert_equal "HEL", nuevo.codigo
  end

  test "create rechaza nombre vacío" do
    assert_no_difference "Proveedor.count" do
      post proveedores_url, params: { proveedor: { nombre: "", tipo: "comercio" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit 200" do
    get edit_proveedor_url(@proveedor)
    assert_response :success
  end

  test "update permite override manual del codigo" do
    patch proveedor_url(@proveedor),
          params: { proveedor: { nombre: @proveedor.nombre, codigo: "tst9", tipo: "comercio" } }
    assert_redirected_to proveedores_url
    @proveedor.reload
    assert_equal "TST9", @proveedor.codigo # normalizado a mayúsculas
  end

  test "buscar JSON permite acceso a usuarios autenticados (no solo admin)" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get buscar_proveedores_url(q: "Test"), headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    assert body.any? { |p| p["nombre"] == @proveedor.nombre }
  end

  test "buscar excluye proveedores inactivos" do
    Proveedor.create!(nombre: "Test Inactivo", tipo: "comercio", activo: false)
    get buscar_proveedores_url(q: "Test Inactivo"), headers: { "Accept" => "application/json" }
    body = JSON.parse(response.body)
    assert body.none? { |p| p["nombre"] == "Test Inactivo" }
  end
end
