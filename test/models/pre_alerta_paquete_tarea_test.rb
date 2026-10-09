require "test_helper"

# C16-01: las `instrucciones` que el cliente escribe en su pre-alerta son una
# **nota** para el que recibe, no una tarea. `PR-9` las convertía en Tarea y
# Yusef lo paró el 2026-08-25: *"el cliente no puede poner una tarea, solo
# nosotros"*. Estos tests fijan que la conversión no vuelva.
class PreAlertaPaqueteTareaTest < ActiveSupport::TestCase
  def crear_pap(instrucciones:, tracking: "1Z999TAREASYNC01")
    PreAlertaPaquete.create!(
      pre_alerta: pre_alertas(:activa),
      tracking: tracking,
      descripcion: "Caja con ropa",
      instrucciones: instrucciones
    )
  end

  test "las instrucciones del cliente NO generan una tarea" do
    assert_no_difference "Tarea.count" do
      crear_pap(instrucciones: "El celular por Express, la ropa por marítimo")
    end
  end

  test "cambiarlas o borrarlas tampoco" do
    pap = crear_pap(instrucciones: "Embolsar todo")

    assert_no_difference "Tarea.count" do
      pap.update!(instrucciones: "Embolsar todo y quitar cajas")
      pap.update!(instrucciones: "")
    end
  end

  test "eliminar el renglon no se lleva una tarea interna que colgaba de el" do
    pap = crear_pap(instrucciones: "Embolsar todo")
    tarea = Tarea.create!(cliente: pre_alertas(:activa).cliente,
                          titulo: "Llamar antes de despachar",
                          pre_alerta_paquete: pap)

    pap.destroy

    tarea.reload
    assert_predicate tarea, :pendiente?
    assert_nil tarea.pre_alerta_paquete_id, "queda colgando del cliente, sin el renglón"
  end

  test "link_tracking! sigue reapuntando al paquete fisico una tarea historica" do
    pap = crear_pap(instrucciones: nil, tracking: "1Z999LINKTAREA1")
    tarea = Tarea.create!(cliente: pre_alertas(:activa).cliente,
                          titulo: "Instrucciones del cliente — 1Z999LINKTAREA1",
                          origen: "pre_alerta", pre_alerta_paquete: pap)
    # El PAP ya trae un paquete "esperado"; lo desvinculamos para simular el
    # caso en que el paquete físico llega por separado.
    pap.update_columns(paquete_id: nil)

    paquete = paquetes(:recibido)
    PreAlertaPaquete.link_tracking!("1Z999LINKTAREA1", paquete)

    assert_equal paquete.id, tarea.reload.paquete_id
  end
end
