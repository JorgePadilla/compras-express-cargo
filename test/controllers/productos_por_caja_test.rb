require "test_helper"

# Los productos son **de cada caja** — `PR-C7.19`.
#
# Jorge, probando la pantalla: *"cambio la cantidad de productos y luego agrego,
# y los números de la derecha no lo suman. Que se pueda cambiar después de
# agregar cajas se siente raro."*
#
# Tenía razón, y la causa de las dos mitades era la misma: `cantidad_productos`
# vivía en el bloque de captura pero **no estaba en `CAMPOS_POR_CAJA`**, así que
# no bajaba con la caja. En un split las N cajas terminaban con el mismo número
# —el último que quedara escrito— y el campo se quedaba ahí, editable,
# pareciendo de la caja que se estaba midiendo.
#
# Lo de los números de la derecha sigue igual y está bien: el panel calcula
# **peso**, y los productos no pesan.
#
# Es la tercera vez que este campo se lee como lo que no es. `PR-C6.18b` existe
# por lo mismo: *"el formulario mostraba Cant. Productos y parecía el campo que
# mandaba"*.
class ProductosPorCajaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id,
                   sucursal_recepcion_id: sucursales(:miami).id }
  end

  def attrs(**extra)
    { tracking: "PROD#{SecureRandom.hex(4)}", cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba", peso: 5 }.merge(extra)
  end

  # El caso que él describió: dos cajas con contenido distinto.
  test "cada caja guarda sus propios productos" do
    post etiquetar_url, params: { paquete: attrs(
      cajas: { "1" => { peso: 40, cantidad_productos: 3 },
               "2" => { peso: 25, cantidad_productos: 7 } }
    ) }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_equal [ 3, 7 ], cajas.map(&:cantidad_productos),
                 "las dos cajas se quedaron con el mismo número"
  end

  # Mismo criterio que las medidas: lo que la caja no dice, lo hereda de arriba.
  test "una caja sin productos hereda el del formulario" do
    post etiquetar_url, params: { paquete: attrs(
      cantidad_productos: 9,
      cajas: { "1" => { peso: 40 }, "2" => { peso: 25, cantidad_productos: 2 } }
    ) }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_equal [ 9, 2 ], cajas.map(&:cantidad_productos)
  end

  test "sin cajas agregadas el paquete suelto guarda el numero de arriba" do
    post etiquetar_url, params: { paquete: attrs(cantidad_productos: 4) }

    assert_equal 4, Paquete.order(:id).last.cantidad_productos
  end

  # Entrega Personal comparte el mismo componente y el mismo concern.
  test "entrega personal tambien los guarda por caja" do
    post entrega_personal_index_url, params: { paquete: {
      cliente_id: clientes(:juan).id, tipo_envio_id: tipo_envios(:cer).id,
      sucursal_recepcion_id: sucursales(:miami).id,
      proveedor_id: proveedores(:driver_entrega).id, descripcion: "EP",
      cajas: { "1" => { peso: 40, cantidad_productos: 3 },
               "2" => { peso: 25, cantidad_productos: 7 } }
    } }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_equal [ 3, 7 ], cajas.map(&:cantidad_productos)
  end

  # La columna Units del Warehouse Receipt estaba escrita a mano como `1` desde
  # siempre: nunca mostró nada. Es justo la que dice cuántas piezas lleva cada
  # bulto.
  test "el Warehouse Receipt muestra los productos de cada caja en Units" do
    post etiquetar_url, params: { paquete: attrs(
      cajas: { "1" => { peso: 40, cantidad_productos: 3 },
               "2" => { peso: 25, cantidad_productos: 7 } }
    ) }
    caja1 = Paquete.order(:id).last(2).min_by(&:numero_caja)

    get warehouse_receipt_paquete_url(caja1)

    assert_response :success
    unidades = css_select("table.wr-pkg tbody tr td:nth-child(3)").map { |td| td.text.strip }
    assert_equal [ "3", "7" ], unidades, "la columna Units seguía en 1"
  end

  test "los paquetes viejos sin el dato siguen mostrando 1" do
    post etiquetar_url, params: { paquete: attrs(cantidad_productos: nil) }
    p = Paquete.order(:id).last

    get warehouse_receipt_paquete_url(p)

    assert_select "table.wr-pkg tbody tr td:nth-child(3)", text: "1"
  end

  # El campo tiene que ser encontrable por el repetidor, que lo busca por
  # `data-caja-campo` y ya no por el target del calculador — los productos no
  # entran en el cálculo y no tienen ese target.
  test "los cinco campos de captura se identifican para el repetidor" do
    get etiquetar_url

    %w[peso alto largo ancho cantidad_productos].each do |campo|
      assert_select "[data-caja-campo='#{campo}']", count: 1,
                    message: "sin `data-caja-campo=#{campo}` el repetidor no lo baja a la fila"
    end
  end
end
