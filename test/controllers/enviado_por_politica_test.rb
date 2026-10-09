require "test_helper"

# C18-06, de punta a punta: marcar «enviado según política» al recibir en
# /etiquetar o en /entrega_personal, o después desde /paquetes, deja el flag,
# los motivos y la nota al cliente, y manda el correo de recibido — que hasta
# acá solo salía cuando el tracking tenía pre-alerta.
class EnviadoPorPoliticaTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @cliente = clientes(:juan)
    @motivo = motivos_envio_politica(:sin_prealerta)
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:cer).id,
                                                 sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "en etiquetar: flag, motivos, nota al cliente, y el correo sale aunque no haya pre-alerta" do
    assert_enqueued_emails 1 do
      post etiquetar_url, params: { paquete: { tracking: "1ZPOLITICA000101", cliente_id: @cliente.id,
                                               descripcion: "Sin identificar", peso: 3,
                                               enviado_por_politica: "1", motivo_envio_politica_ids: [ @motivo.id ],
                                               notas_envio_politica: "Solo decía Juan" } }
    end

    p = Paquete.find_by!(tracking: "1ZPOLITICA000101")
    assert_predicate p, :enviado_por_politica?
    assert_equal [ @motivo ], p.motivos_envio_politica.to_a
    assert_includes p.notas_al_cliente, @motivo.texto_al_cliente
    assert_includes p.notas_al_cliente, "Solo decía Juan"
  end

  test "un recibido sin pre-alerta y sin politica no manda correo" do
    assert_no_enqueued_emails do
      post etiquetar_url, params: { paquete: { tracking: "1ZPOLITICA000102", cliente_id: @cliente.id,
                                               descripcion: "Normal", peso: 3 } }
    end
  end

  test "pre-alertado Y con politica manda UN correo, no dos" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), titulo: "x", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: "1ZPOLITICA000103", descripcion: "Anunciado")

    assert_enqueued_emails 1 do
      post etiquetar_url, params: { paquete: { tracking: "1ZPOLITICA000103", cliente_id: @cliente.id,
                                               descripcion: "x", peso: 3,
                                               enviado_por_politica: "1", motivo_envio_politica_ids: [ @motivo.id ] } }
    end
  end

  test "en un split se manda un correo por envio, no uno por caja" do
    assert_enqueued_emails 1 do
      post etiquetar_url, params: { paquete: { tracking: "1ZPOLITICA000104", cliente_id: @cliente.id,
                                               descripcion: "Dos cajas", enviado_por_politica: "1",
                                               motivo_envio_politica_ids: [ @motivo.id ],
                                               cajas: { "1" => { peso: 2 }, "2" => { peso: 3 } } } }
    end
    assert Paquete.where(tracking: "1ZPOLITICA000104").all?(&:enviado_por_politica?)
  end

  test "en entrega personal tambien, y sin politica no manda nada" do
    # Ojo: EP exige un proveedor de entrega personal; sin él el create devuelve
    # 422 y un `assert_no_enqueued_emails` pasa sin probar nada.
    ep = { cliente_id: @cliente.id, tipo_envio_id: tipo_envios(:cer).id, peso: 2,
           proveedor_id: proveedores(:driver_entrega).id, sucursal_id: sucursales(:miami).id,
           sucursal_recepcion_id: sucursales(:miami).id }

    assert_difference("Paquete.count") do
      assert_no_enqueued_emails do
        post entrega_personal_index_url, params: { paquete: ep.merge(descripcion: "Traído") }
      end
    end

    assert_difference("Paquete.count") do
      assert_enqueued_emails 1 do
        post entrega_personal_index_url, params: { paquete: ep.merge(descripcion: "Traído sin nombre",
                                                                     enviado_por_politica: "1",
                                                                     motivo_envio_politica_ids: [ @motivo.id ]) }
      end
    end
    assert_includes Paquete.order(:id).last.notas_al_cliente, @motivo.texto_al_cliente
  end

  test "corregirlo despues desde /paquetes tambien avisa, una vez" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    paquete = paquetes(:recibido)

    assert_enqueued_emails 1 do
      patch paquete_url(paquete), params: { paquete: { enviado_por_politica: "1",
                                                       motivo_envio_politica_ids: [ @motivo.id ] } }
    end
    assert_includes paquete.reload.notas_al_cliente, @motivo.texto_al_cliente

    assert_no_enqueued_emails do
      patch paquete_url(paquete), params: { paquete: { descripcion: "otra" } }
    end
  end

  test "marcarla al actualizar en /etiquetar tambien avisa, una vez" do
    paquete = paquetes(:recibido)

    assert_enqueued_emails 1 do
      patch actualizar_etiquetar_url(paquete), params: { paquete: { enviado_por_politica: "1",
                                                                    motivo_envio_politica_ids: [ @motivo.id ] } }
    end
    assert_includes paquete.reload.notas_al_cliente, @motivo.texto_al_cliente

    assert_no_enqueued_emails do
      patch actualizar_etiquetar_url(paquete), params: { paquete: { descripcion: "otra" } }
    end
  end

  test "sin correo del cliente no se manda nada, pero la nota queda" do
    @cliente.update_columns(email: nil)

    assert_no_enqueued_emails do
      post etiquetar_url, params: { paquete: { tracking: "1ZPOLITICA000105", cliente_id: @cliente.id,
                                               descripcion: "x", peso: 3, enviado_por_politica: "1",
                                               motivo_envio_politica_ids: [ @motivo.id ] } }
    end
    assert_includes Paquete.find_by!(tracking: "1ZPOLITICA000105").notas_al_cliente, @motivo.texto_al_cliente
  end

  test "las tres pantallas cargan el catalogo" do
    get etiquetar_url
    assert_match(/Enviado según política/, response.body)
    assert_match(/#{@motivo.nombre}/, response.body)

    get new_entrega_personal_url
    assert_match(/Enviado según política/, response.body)

    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    get paquete_url(paquetes(:recibido), mode: "edit")
    assert_match(/Enviado según política/, response.body)
  end
end
