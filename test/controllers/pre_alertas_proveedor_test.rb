require "test_helper"

# PR-C6.36: el proveedor de la pre-alerta sugiere del catálogo, sin dejar de
# aceptar texto libre.
#
# Era el último cabo suelto del plan de la Conversación 6. En `/pre_alertas` el
# proveedor se tecleaba a mano y sin ayuda, mientras el form de paquete ya usa
# el catálogo de `Proveedor`. Cada quien escribía "Amazon", "amazon" o "AMZN" y
# después no se podía agrupar nada.
#
# **Por qué un `datalist` y no una FK.** `PreAlerta.proveedor` es un string;
# migrarlo a `proveedor_id` obligaría a mapear los valores viejos a mano por
# una pantalla que nadie reportó rota. El `datalist` da las sugerencias sin
# tocar el esquema ni los datos.
#
# Y es el mismo patrón que Yusef ya aprobó para el carrier de /etiquetar:
# "dropdown con texto libre para agregar a la lista".
class PreAlertasProveedorTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @proveedor = proveedores(:driver_entrega)
  end

  test "el form sugiere los proveedores del catalogo" do
    get new_pre_alerta_url

    assert_match(/<datalist id="proveedores-list">/, response.body)
    assert_match(/<option value="#{@proveedor.nombre}">/, response.body)
  end

  test "el campo queda enganchado a la lista" do
    get new_pre_alerta_url

    campo = response.body[/<input[^>]*name="pre_alerta\[proveedor\]"[^>]*>/].to_s
    assert_match(/list="proveedores-list"/, campo)
  end

  test "editar tambien sugiere" do
    get edit_pre_alerta_url(pre_alertas(:activa))

    assert_match(/<datalist id="proveedores-list">/, response.body)
  end

  test "sigue aceptando un proveedor que no esta en el catalogo" do
    # Es lo que hace que el patrón sirva: el operario no se queda trabado si el
    # proveedor todavía no existe. Yusef pidió "texto libre para agregar a la
    # lista", no una lista cerrada.
    pa = pre_alertas(:activa)

    patch pre_alerta_url(pa), params: { pre_alerta: { proveedor: "Tienda Nueva SA" } }

    assert_equal "Tienda Nueva SA", pa.reload.proveedor
  end

  test "el re-render de un error tambien trae las sugerencias" do
    # Este camino se me escapó la primera vez y reventó la pantalla entera con
    # `undefined method 'each' for nil`: el `create` fallido re-renderiza `new`
    # sin pasar por la acción que carga el catálogo. Por eso la carga vive en
    # un método y no repetida en cada acción.
    assert_no_difference "PreAlerta.count" do
      post pre_alertas_url, params: { pre_alerta: { titulo: "Sin cliente" } }
    end

    assert_response :unprocessable_entity
    assert_match(/<datalist id="proveedores-list">/, response.body)
  end

  test "un proveedor inactivo no se sugiere" do
    @proveedor.update!(activo: false)

    get new_pre_alerta_url

    assert_no_match(/<option value="#{@proveedor.nombre}">/, response.body)
  end
end
