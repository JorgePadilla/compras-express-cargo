require "test_helper"

# Los grupos de clientes **ya no tienen pantalla propia**.
#
# Jorge, por segunda vez: *"el área de categoría de precio, pensaría que se puede
# eliminar porque no le veo mucho valor… al menos que para vos sí lo tenga y
# definitivamente no se pueda eliminar"*.
#
# La tabla no se puede eliminar —los 8 grupos son las 8 columnas del Excel de
# Yusef y 28 de las 44 tarifas cuelgan de ellos— pero la pantalla sí sobraba. Se
# fue en `PR-C7.12`; lo que queda de este controller es renombrar y borrar, que
# se llaman desde `/servicios`.
class CategoriaPreciosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @categoria = categoria_precios(:regular)
  end

  # La URL vieja se queda viva por los bookmarks, pero manda a donde ahora se
  # administran los grupos.
  test "el listado viejo redirige a la Tabla de Servicios" do
    get categoria_precios_url

    assert_redirected_to servicios_url
  end

  # El detalle mostraba "qué cobra este grupo". Eso está en /servicios, fila por
  # fila. La URL se queda viva para no romper bookmarks.
  test "el detalle viejo tambien redirige" do
    get categoria_precio_url(@categoria)

    assert_redirected_to servicios_url
  end

  test "should get new" do
    get new_categoria_precio_url
    assert_response :success
  end

  test "should create categoria_precio" do
    assert_difference "CategoriaPrecio.count", 1 do
      post categoria_precios_url, params: {
        categoria_precio: { nombre: "Nueva" }
      }
    end
    assert_redirected_to servicios_url
  end

  test "should not create invalid" do
    assert_no_difference "CategoriaPrecio.count" do
      post categoria_precios_url, params: { categoria_precio: { nombre: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_categoria_precio_url(@categoria)
    assert_response :success
  end

  test "should update" do
    patch categoria_precio_url(@categoria), params: {
      categoria_precio: { nombre: "Regular Updated" }
    }
    assert_redirected_to servicios_url
    assert_equal "Regular Updated", @categoria.reload.nombre
  end

  test "non-admin cannot access" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get categoria_precios_url
    assert_redirected_to root_url
  end

  # Jorge: "¿se puede eliminar categorías de precios?". La tabla se queda —es el
  # nivel 3 de la cascada de precios— pero tenía razón en lo literal: la ruta era
  # `except: :destroy` y no había forma de sacar una que ya no se usaba.
  test "se puede borrar un grupo que no usa nadie" do
    categoria = CategoriaPrecio.create!(nombre: "Sobrante")

    assert_difference "CategoriaPrecio.count", -1 do
      delete categoria_precio_url(categoria)
    end

    assert_redirected_to servicios_url
  end

  test "no se borra un grupo con clientes, y el mensaje dice por que" do
    categoria = categoria_precios(:regular)
    clientes(:juan).update!(categoria_precio: categoria)

    assert_no_difference "CategoriaPrecio.count" do
      delete categoria_precio_url(categoria)
    end

    assert_match(/cliente/i, flash[:alert])
  end

  test "no se borra un grupo con tarifas cargadas" do
    categoria = categoria_precios(:vip)
    Tarifa.create!(tipo_envio: tipo_envios(:cer), categoria_precio: categoria,
                   desde_libras: 0, precio_libra: 3.0, moneda: "USD", activo: true)

    assert_no_difference "CategoriaPrecio.count" do
      delete categoria_precio_url(categoria)
    end

    assert_match(/tarifa/i, flash[:alert])
  end
end
