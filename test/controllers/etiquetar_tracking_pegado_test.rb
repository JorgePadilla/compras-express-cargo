require "test_helper"

# C29-01 · /etiquetar guarda el tracking que llegó con el espacio del
# copy-paste. La consulta del JS ya recortaba —decía «libre»— y el guardado lo
# rechazaba con *"no permite espacios ni símbolos"*.
class EtiquetarTrackingPegadoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "una caja" do
    assert_difference("Paquete.count") do
      post etiquetar_url, params: { paquete: attrs("  PEGADO123456 ") }
    end
    assert_equal "PEGADO123456", Paquete.order(:id).last.tracking
  end

  test "un split" do
    assert_difference("Paquete.count", 2) do
      post etiquetar_url, params: { paquete: attrs(" PEGADOSPLIT99 ").merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 } }) }
    end
    assert_equal [ "PEGADOSPLIT99" ], Paquete.order(:id).last(2).map(&:tracking).uniq
  end

  private

  def attrs(tracking)
    { tracking: tracking, cliente_id: clientes(:juan).id, descripcion: "Ropa", peso: 5 }
  end
end
