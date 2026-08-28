require "test_helper"

# C19-05: el modal de duplicado de /etiquetar mostraba solo la fecha
# (`%d/%m/%Y`), así que el operario no distinguía el paquete recibido hace 10
# minutos del de las 8am — que es exactamente lo que Yusef estaba mirando
# cuando la "incongruencia" no reprodujo (RP-47): el paquete resultó recibido
# hacía 3 minutos.
class CheckTrackingFechaConSegundosTest < ActionDispatch::IntegrationTest
  test "la fecha del duplicado lleva hora y segundos" do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }

    paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                              tracking: "1ZSEGUNDOS000001", descripcion: "x",
                              estado: "recibido_miami", user: users(:digitador),
                              sucursal_recepcion: sucursales(:miami))
    paquete.update_columns(fecha_recibido_miami: Time.zone.local(2026, 8, 28, 10, 15, 47))

    get check_tracking_paquetes_url(tracking: paquete.tracking), as: :json

    data = JSON.parse(response.body)
    assert data["exists"]
    assert_equal "28/08/2026 10:15:47", data["fecha"]
  end
end
