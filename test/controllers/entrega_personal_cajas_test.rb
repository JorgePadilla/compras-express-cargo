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
#
# A7-20: el campo "cantidad de cajas" ya no existe en esta pantalla — las cajas
# se agregan una por una y **la cantidad sale de contar las filas**. La lección
# de PR-C6.31 sigue siendo la misma y por eso estos tests siguen acá: si hay dos
# fuentes para el mismo número, alguna va a mentir. Ahora hay una sola.
class EntregaPersonalCajasTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "guarda una caja por cada fila agregada" do
    assert_difference "Paquete.count", 3 do
      post entrega_personal_index_url, params: {
        paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 12 } })
      }
    end

    assert_equal [ 1, 2, 3 ], Paquete.order(:id).last(3).map(&:numero_caja)
  end

  test "cada caja guarda su propio peso" do
    post entrega_personal_index_url, params: {
      paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 30 } })
    }

    pesos = Paquete.order(:id).last(2).sort_by(&:numero_caja).map { |p| p.peso.to_f }
    assert_equal [ 5.0, 30.0 ], pesos,
                 "las medidas por caja se perdieron: se guardaron todas iguales"
  end

  test "sin agregar ninguna caja se guarda un solo bulto" do
    # El caso común: una caja, el operario nunca toca Agregar y llena el peso
    # de arriba.
    assert_difference "Paquete.count", 1 do
      post entrega_personal_index_url, params: { paquete: attrs }
    end
  end

  test "una sola caja agregada manda sus propios datos" do
    assert_difference "Paquete.count", 1 do
      post entrega_personal_index_url, params: {
        paquete: attrs.merge(peso: 5, cajas: { "1" => { peso: 22 } })
      }
    end

    assert_equal 22.0, Paquete.order(:id).last.peso.to_f,
                 "se guardó el peso de captura en vez del de la caja agregada"
  end

  test "el formulario ya no tiene un campo de cantidad que pueda mentir" do
    # La causa raíz de PR-C6.31 era tener dos campos con el mismo `name`: el
    # último ganaba y el split se caía en silencio. Ahora no hay ninguno — la
    # cantidad se cuenta de las filas, así que no hay dos fuentes que discrepen.
    get new_entrega_personal_url

    campos = response.body.scan(/name="paquete\[cantidad_paquetes\]"/).size
    assert_equal 0, campos,
                 "volvió un campo `cantidad_paquetes` a Entrega Personal; la cantidad sale de las filas"
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
