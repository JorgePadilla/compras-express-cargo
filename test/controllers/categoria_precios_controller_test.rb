require "test_helper"

class CategoriaPreciosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @categoria = categoria_precios(:regular)
  end

  test "should get index" do
    get categoria_precios_url
    assert_response :success
  end

  test "should get new" do
    get new_categoria_precio_url
    assert_response :success
  end

  test "should create categoria_precio" do
    assert_difference "CategoriaPrecio.count", 1 do
      post categoria_precios_url, params: {
        categoria_precio: {
          nombre: "Nueva", precio_libra_aereo: 5.0,
          precio_libra_maritimo: 2.0, precio_volumen: 0.01
        }
      }
    end
    assert_redirected_to categoria_precios_url
  end

  test "should not create invalid" do
    assert_no_difference "CategoriaPrecio.count" do
      post categoria_precios_url, params: { categoria_precio: { nombre: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should show" do
    get categoria_precio_url(@categoria)
    assert_response :success
  end

  test "should get edit" do
    get edit_categoria_precio_url(@categoria)
    assert_response :success
  end

  test "should update" do
    patch categoria_precio_url(@categoria), params: {
      categoria_precio: { nombre: "Regular Updated" }
    }
    assert_redirected_to categoria_precios_url
    assert_equal "Regular Updated", @categoria.reload.nombre
  end

  test "non-admin cannot access" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get categoria_precios_url
    assert_redirected_to root_url
  end
end
