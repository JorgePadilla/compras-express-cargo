require "test_helper"

# C20-01: el error que se volvía pantalla 500 y le tapaba al operario lo que
# había que corregir.
#
# En los logs de staging, una y otra vez:
#
#   ActionView::Template::Error (undefined method `any?' for nil)
#   app/controllers/etiquetar_controller.rb:467:in `render_create_error'
#
# `index` cargaba `@supervisores_cobro` (PR-C6.28) y `render_create_error` no
# —eran dos copias del mismo bloque de assigns y una se quedó atrás—. La vista
# lo usa en el banner del cobro por cambio de servicio, que sale cuando
# `@modo_actualizacion && @paquete.solicito_cambio_servicio?`. O sea que
# **cualquier** error al actualizar un paquete con cambio de servicio moría en
# la vista: el 422 con el mensaje que explicaba el problema nunca llegaba a la
# pantalla. Yusef, probando en vivo: *"ahí tira el rojo"* — y ninguno de los
# dos podía ver por qué.
#
# Los tres caminos de error del update, con el paquete ya marcado con cambio
# de servicio, que es la condición que destapaba el banner.
class EtiquetarErrorNoEs500Test < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }

    # Con el cobro por cambio de servicio ya puesto: es lo que hace aparecer el
    # banner que reventaba.
    @paquete = Paquete.create!(
      tracking: "ERR#{SecureRandom.hex(4)}",
      cliente: clientes(:juan), tipo_envio: @cer, sucursal_recepcion: @miami,
      estado: "recibido_miami", descripcion: "Perfumes", peso: 5,
      solicito_cambio_servicio: true, user: @user
    )
  end

  test "marcar cambio de servicio sin elegir destino avisa, no revienta" do
    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { descripcion: "otra cosa", solicito_cambio_servicio: "1" }
    }

    assert_response :unprocessable_entity
    assert_match(/elegí a qué tipo de envío cambia/i, response.body)
    assert_match "cobro-cambio-servicio", response.body,
                 "el banner del cobro tiene que poder renderizarse"
  end

  test "una caja que ya se cobró avisa cuál, no revienta" do
    caja2 = Paquete.create!(
      tracking: @paquete.tracking, cliente: @paquete.cliente, tipo_envio: @cer,
      sucursal_recepcion: @miami, numero_recepcion: @paquete.numero_recepcion,
      estado: "pre_facturado", descripcion: "Perfumes", peso: 5,
      numero_caja: 2, cantidad_paquetes: 2, user: @user
    )
    @paquete.update_columns(numero_caja: 1, cantidad_paquetes: 2)

    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { descripcion: "otra cosa", cantidad_paquetes: 1 }
    }

    assert_response :unprocessable_entity
    assert_match(/no se puede bajar a 1 cajas/i, response.body)
    assert Paquete.exists?(caja2.id), "la caja cobrada no se borra"
  end

  test "un paquete que no valida avisa, no revienta" do
    patch actualizar_etiquetar_url(@paquete), params: {
      paquete: { tracking: "" }
    }

    assert_response :unprocessable_entity
    assert_match(/no se pudo actualizar/i, response.body)
  end

  # La red que evita que esto vuelva: los dos caminos tienen que dibujar la
  # pantalla con las mismas piezas.
  test "el 422 trae lo mismo que un GET limpio" do
    get etiquetar_url
    assert_response :success

    patch actualizar_etiquetar_url(@paquete), params: { paquete: { tracking: "" } }
    assert_response :unprocessable_entity

    # Muestras de cada assign compartido: servicios, sucursal, carriers,
    # motivos de retención y de política.
    assert_match @cer.nombre, response.body
    assert_match "carriers-list", response.body
    assert_match MotivoRetencion.activos.ordered.first.nombre, response.body
    assert_match MotivoEnvioPolitica.activos.ordered.first.nombre, response.body
  end
end
