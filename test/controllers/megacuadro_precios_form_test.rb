require "test_helper"

# El megacuadro cableado a la ficha del cliente (`A7-26` · `PR-C7.15`).
#
# Yusef: *"ese precio especial para un cliente debería estar en el cliente…
# **entro al cliente y le pongo el precio especial**"*.
#
# La lógica del diff se prueba en `test/services/precios_especiales_del_cliente_test.rb`.
# Acá se prueba lo otro: que el formulario lo mande, que el controller lo aplique
# junto con el cliente, y que un error de precio no deje medio guardado.
class MegacuadroPreciosFormTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @cliente = clientes(:juan)
    @cer     = tipo_envios(:cer)
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")   # precio de lista
  end

  test "el formulario trae una celda de precio por servicio" do
    get edit_cliente_url(@cliente)

    assert_response :success
    assert_select "input[name=?]", "precios_especiales[#{@cer.id}][precio]"
    assert_select "input[name=?]", "precios_especiales[#{@cer.id}][minimo_con_isv]"
  end

  # La columna que hace que no se negocie a ciegas. Manalo: "eso de tener un
  # montón de precios siempre es mala idea"; Yusef: "estandarizar la mayoría y
  # crearle botones para las excepciones".
  test "el formulario muestra contra que se esta negociando" do
    get edit_cliente_url(@cliente)

    assert_select "td", { text: /4\.50\/lb/, count: 1 }
    assert_match(/Paga hoy/i, response.body)
  end

  test "guardar el cliente le crea el precio especial" do
    assert_difference "Tarifa.count", 1 do
      patch cliente_url(@cliente), params: {
        cliente: { nombre: @cliente.nombre },
        precios_especiales: { @cer.id.to_s => { precio: "3.50" } }
      }
    end

    assert_redirected_to cliente_url(@cliente)
    assert_equal BigDecimal("3.50"),
                 Tarifa.find_by(cliente_id: @cliente.id, tipo_envio_id: @cer.id).precio_libra
  end

  test "vaciar la celda se lo quita" do
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, precio_libra: 3.50, moneda: "USD")

    assert_difference "Tarifa.count", -1 do
      patch cliente_url(@cliente), params: {
        cliente: { nombre: @cliente.nombre },
        precios_especiales: { @cer.id.to_s => { precio: "" } }
      }
    end
  end

  # Media negociación aplicada —el cliente con su grupo nuevo pero sin el precio
  # que lo acompaña— cobraría mal hasta que alguien se diera cuenta.
  test "si el precio no pasa validacion el cliente tampoco se guarda" do
    patch cliente_url(@cliente), params: {
      cliente: { nombre: "Nombre Nuevo" },
      precios_especiales: { @cer.id.to_s => { precio: "-1" } }
    }

    assert_response :unprocessable_entity
    assert_not_equal "Nombre Nuevo", @cliente.reload.nombre,
                     "el cliente se guardó aunque su precio falló"
  end

  test "el error dice en que servicio fue" do
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, desde_libras: 0, hasta_libras: 50,
                   precio_libra: 4.00, moneda: "USD")
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, desde_libras: 50,
                   precio_libra: 3.50, moneda: "USD")

    patch cliente_url(@cliente), params: {
      cliente: { nombre: @cliente.nombre },
      precios_especiales: { @cer.id.to_s => { precio: "1.00" } }
    }

    assert_response :unprocessable_entity
    assert_match(/CER/, flash[:alert])
  end

  # El alta no puede tener precios —no hay a quién colgárselos— pero sí el cobro
  # por volumen: "es lo que le creamos al cliente, cuando creamos el cliente".
  test "en el alta las celdas de precio van deshabilitadas" do
    get new_cliente_url

    assert_response :success
    assert_select "input[name=?][disabled]", "precios_especiales[#{@cer.id}][precio]"
    assert_select "input[name=?]:not([disabled])", "cliente[tipo_envio_solo_volumetrico_ids][]"
  end

  # El bug recurrente de este repo: el arreglo llega a una pantalla y no a su
  # gemela. Los checkboxes de solo-volumétrico **se mudaron** al cuadro.
  test "los checkboxes de solo volumen viven solo en el cuadro" do
    get edit_cliente_url(@cliente)

    assert_select "input[name=?][type=checkbox]", "cliente[tipo_envio_solo_volumetrico_ids][]",
                  count: TipoEnvio.activos.count
  end

  test "guardar sin mandar precios no le toca las tarifas al cliente" do
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, precio_libra: 3.50, moneda: "USD")

    assert_no_difference "Tarifa.count" do
      patch cliente_url(@cliente), params: { cliente: { nombre: @cliente.nombre } }
    end
  end
end
