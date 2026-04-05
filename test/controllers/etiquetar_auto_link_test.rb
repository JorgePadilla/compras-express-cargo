require "test_helper"

class EtiquetarAutoLinkTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
  end

  test "creating a paquete auto-links matching pre_alerta_paquete" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    tracking = pap.tracking

    assert_nil pap.paquete_id

    post etiquetar_url, params: { paquete: {
      tracking: tracking,
      cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:aereo).id,
      peso: 3.0
    } }

    pap.reload
    assert_not_nil pap.paquete_id
    assert_equal "recibido", pap.pre_alerta.reload.estado
  end

  test "auto-link sends notification email" do
    pap = pre_alerta_paquetes(:pap_sin_vincular)

    assert_enqueued_emails 1 do
      post etiquetar_url, params: { paquete: {
        tracking: pap.tracking,
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        peso: 2.0
      } }
    end
  end

  test "creating a paquete with non-matching tracking does not link" do
    assert_no_enqueued_emails do
      post etiquetar_url, params: { paquete: {
        tracking: "NOMATCH999",
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:aereo).id,
        peso: 1.0
      } }
    end
  end
end
