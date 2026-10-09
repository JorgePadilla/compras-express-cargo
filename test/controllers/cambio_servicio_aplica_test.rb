require "test_helper"

# PR-C6.8: marcar "cambio de servicio" pregunta a cuál, y lo aplica.
#
# En las notas de Jorge quedó escrito el repro exacto:
#
#   "cambio de servicio → CER a CKM **no funciona**"
#
# Yusef marcó el flag, eligió CKM, guardó — y el paquete se quedó en CER. El
# flag solo decía "alguien pidió el cambio"; nada aplicaba el destino.
#
# Importa porque el cambio **genera un cargo automático** en la pre-factura:
# el paquete quedaba cobrando el cargo sin haberse movido de servicio.
class CambioServicioAplicaTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @ckm = tipo_envios(:ckm)
    @miami = sucursales(:miami)
    iniciar_sesion_en(@cer)
  end

  test "el repro de Yusef: CER a CKM ahora si funciona" do
    post etiquetar_url, params: {
      paquete: attrs.merge(solicito_cambio_servicio: "1", tipo_envio_destino_id: @ckm.id)
    }

    p = Paquete.order(:id).last
    assert_equal @ckm, p.tipo_envio, "se quedó en el tipo de la sesión"
    assert p.solicito_cambio_servicio?
  end

  test "queda registrado de que servicio venia" do
    # El cargo automático se le cobra al cliente. Cuando reclame, hay que
    # poder decirle de qué a qué se movió.
    post etiquetar_url, params: {
      paquete: attrs.merge(solicito_cambio_servicio: "1", tipo_envio_destino_id: @ckm.id)
    }

    p = Paquete.order(:id).last
    assert_equal @cer, p.tipo_envio_anterior
    assert_equal "CER → CKM", p.cambio_servicio_label
  end

  test "marcar el flag sin elegir destino no guarda nada" do
    # Antes se guardaba a medias: el flag prendido sobre el tipo viejo, o sea
    # cobrando un cargo por un cambio que nunca pasó.
    assert_no_difference -> { Paquete.count } do
      post etiquetar_url, params: { paquete: attrs.merge(solicito_cambio_servicio: "1") }
    end

    assert_response :unprocessable_entity
    assert_match(/elegí a qué tipo de envío cambia/i, flash[:alert].to_s)
  end

  test "sin cambio de servicio manda el tipo de la sesion" do
    post etiquetar_url, params: { paquete: attrs }

    p = Paquete.order(:id).last
    assert_equal @cer, p.tipo_envio
    assert_nil p.tipo_envio_anterior
    assert_not p.solicito_cambio_servicio?
  end

  test "las N cajas de un split cambian todas al mismo servicio" do
    # Es el mismo tracking: no se parte en dos servicios distintos.
    post etiquetar_url, params: {
      paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 } },
                           solicito_cambio_servicio: "1",
                           tipo_envio_destino_id: @ckm.id)
    }

    cajas = Paquete.order(:id).last(3)
    assert_equal [ @ckm ], cajas.map(&:tipo_envio).uniq
    assert_equal [ @cer ], cajas.map(&:tipo_envio_anterior).uniq
  end

  test "un split con el flag y sin destino tampoco guarda" do
    assert_no_difference -> { Paquete.count } do
      post etiquetar_url, params: {
        paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 } }, solicito_cambio_servicio: "1")
      }
    end

    assert_response :unprocessable_entity
  end

  test "elegir el mismo servicio de la sesion no marca cambio" do
    # No es un cambio: no debe cobrar cargo ni ensuciar el rastro.
    post etiquetar_url, params: {
      paquete: attrs.merge(solicito_cambio_servicio: "1", tipo_envio_destino_id: @cer.id)
    }

    p = Paquete.order(:id).last
    assert_equal @cer, p.tipo_envio
    assert_nil p.tipo_envio_anterior, "se registró un cambio que no ocurrió"
  end

  private

  def iniciar_sesion_en(tipo)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo.id, sucursal_recepcion_id: @miami.id }
  end

  def attrs
    {
      tracking: "CS#{SecureRandom.hex(4)}",
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
