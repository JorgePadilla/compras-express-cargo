require "test_helper"

# PR-C6.31: en Entrega Personal la cantidad de cajas se perdía al guardar.
#
# Jorge, probándolo el 2026-08-09: "cuando son varias cajas no veo que tenga
# varias líneas para ingresar las medidas de las diferentes cajas".
#
# La pantalla **sí** las pinta —lo verifiqué en staging, con 3 cajas salen las
# 3 filas—, pero el guardado las tiraba: el form arrastraba un
# `hidden_field :cantidad_paquetes, value: 1` de la época del modal de F9, y
# quedaba **después** del partial compartido en el DOM. Con dos campos del
# mismo nombre, Rails se queda con el último: siempre 1.
#
# O sea que el operario ponía 3, veía 3 filas, las llenaba, guardaba… y se
# grababa un solo paquete. Silencioso, y en el flujo donde el cliente está
# parado enfrente en el mostrador.
class EntregaPersonalCajasTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "guarda una caja por cada una que se pidio" do
    assert_difference "Paquete.count", 3 do
      post entrega_personal_index_url, params: { paquete: attrs.merge(cantidad_paquetes: 3) }
    end

    assert_equal [ 1, 2, 3 ], Paquete.order(:id).last(3).map(&:numero_caja)
  end

  test "cada caja guarda su propio peso" do
    post entrega_personal_index_url, params: {
      paquete: attrs.merge(
        cantidad_paquetes: 2,
        cajas: { "1" => { peso: 5 }, "2" => { peso: 30 } }
      )
    }

    pesos = Paquete.order(:id).last(2).sort_by(&:numero_caja).map { |p| p.peso.to_f }
    assert_equal [ 5.0, 30.0 ], pesos,
                 "las medidas por caja se perdieron: se guardaron todas iguales"
  end

  test "una sola caja sigue guardando un solo paquete" do
    assert_difference "Paquete.count", 1 do
      post entrega_personal_index_url, params: { paquete: attrs.merge(cantidad_paquetes: 1) }
    end
  end

  test "el formulario no manda dos veces la cantidad de cajas" do
    # La causa raíz. Si vuelve a haber dos campos con el mismo `name`, el
    # último gana y el split se cae en silencio — sin error, sin aviso.
    get new_entrega_personal_url

    campos = response.body.scan(/name="paquete\[cantidad_paquetes\]"/).size
    assert_equal 1, campos,
                 "hay #{campos} campos `cantidad_paquetes` en el form; el último pisa al otro"
  end

  private

  def attrs
    {
      cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:cer).id,
      sucursal_id: sucursales(:miami).id,
      proveedor_id: proveedores(:driver_entrega).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
