require "test_helper"

# La bitácora de autorizaciones se escribió para pre-facturas y notas, que
# tienen `numero`. Desde C24-01 (excepción de cobro) y C28-13 (medir con
# faltantes) el documento puede ser un **paquete**, y `documento.numero`
# reventaba la página entera.
class BitacoraAutorizacionesTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end

  test "una autorización sobre un paquete se lista con su warehouse" do
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    paquete = paquetes(:recibido)
    Autorizacion.create!(documento: paquete, solicitado_por: supervisor, autorizado_por: supervisor,
                         accion: "medicion_con_faltantes", concepto: "PA-X", motivo: "no aparece",
                         detalle: "Faltaban 1", pin: "1234")

    get autorizaciones_path

    assert_response :success
    assert_select "a[href=?]", paquete_path(paquete)
    assert_match "Medido con faltantes", response.body
  end
end
