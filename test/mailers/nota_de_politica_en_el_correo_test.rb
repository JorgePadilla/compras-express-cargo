require "test_helper"

# C18-06: `notas_al_cliente` viaja en el correo de recibido — el canal
# documentado desde abril (*"viaja en el correo de notificación al cliente
# cuando llega la carga a Miami"*) y que nunca había viajado (`docs/06`).
class NotaDePoliticaEnElCorreoTest < ActionMailer::TestCase
  test "con nota, el correo la lleva en html y en texto" do
    paquete = paquetes(:recibido)
    paquete.update!(notas_al_cliente: "Enviado según política de envío por falta de identificación.")

    mail = PreAlertaMailer.paquete_recibido(paquete.cliente, paquete)

    assert_includes mail.html_part.body.to_s, "Enviado según política de envío por falta de identificación."
    assert_includes mail.text_part.body.to_s, "Enviado según política de envío por falta de identificación."
    assert_includes mail.html_part.body.to_s, "Nota sobre este paquete"
  end

  test "el correo nombra la sucursal donde se recibio; un paquete sin ella dice Miami" do
    # Seguimiento de C18-02: decía «bodega de Miami» fijo aunque se recibiera
    # en DF México.
    paquete = paquetes(:recibido)
    mexico = Sucursal.create!(codigo: "DFM", nombre: "DF México", pais: "México", ubicacion: "otros",
                              activo: true, recibe_carga: true)
    paquete.update_columns(sucursal_recepcion_id: mexico.id)

    mail = PreAlertaMailer.paquete_recibido(paquete.cliente, paquete)
    assert_includes mail.html_part.body.to_s, "bodega de DF México"
    assert_includes mail.text_part.body.to_s, "bodega de DF México"
    assert_includes mail.subject, "recibido en DF México"

    paquete.update_columns(sucursal_recepcion_id: nil)
    mail = PreAlertaMailer.paquete_recibido(paquete.cliente, paquete)
    assert_includes mail.html_part.body.to_s, "bodega de Miami"
  end

  test "sin nota, el correo es el de siempre" do
    paquete = paquetes(:recibido)
    paquete.update!(notas_al_cliente: nil)

    mail = PreAlertaMailer.paquete_recibido(paquete.cliente, paquete)

    assert_not_includes mail.html_part.body.to_s, "Nota sobre este paquete"
    assert_includes mail.html_part.body.to_s, paquete.tracking
  end
end
