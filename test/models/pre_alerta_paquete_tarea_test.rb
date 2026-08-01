require "test_helper"

# PR-9.a: las `instrucciones` que el cliente escribe en su pre-alerta se
# materializan como Tarea, para que el digitador las vea con checkbox en la
# franja de /etiquetar en vez de que queden sepultadas en un textarea.
class PreAlertaPaqueteTareaTest < ActiveSupport::TestCase
  def crear_pap(instrucciones:, tracking: "1Z999TAREASYNC01")
    PreAlertaPaquete.create!(
      pre_alerta: pre_alertas(:activa),
      tracking: tracking,
      descripcion: "Caja con ropa",
      instrucciones: instrucciones
    )
  end

  test "instrucciones generan una tarea de miami que no bloquea el avance" do
    pap = crear_pap(instrucciones: "El celular por Express, la ropa por marítimo")

    tarea = Tarea.find_by(pre_alerta_paquete_id: pap.id)
    assert_not_nil tarea
    assert_equal "pre_alerta", tarea.origen
    assert_equal "miami", tarea.departamento
    assert_equal pre_alertas(:activa).cliente_id, tarea.cliente_id
    assert_equal "El celular por Express, la ropa por marítimo", tarea.descripcion
    assert_includes tarea.titulo, pap.tracking
    assert_not tarea.bloquea_avance,
               "una instrucción del cliente no debe congelar la transición pre_alerta_estado → empacado"
  end

  test "pre alerta sin instrucciones no genera tarea" do
    pap = crear_pap(instrucciones: nil)

    assert_nil Tarea.find_by(pre_alerta_paquete_id: pap.id)
  end

  test "re-guardar no duplica la tarea" do
    pap = crear_pap(instrucciones: "Embolsar todo")

    pap.update!(instrucciones: "Embolsar todo y quitar cajas")
    pap.update!(descripcion: "Otra descripcion")

    assert_equal 1, Tarea.where(pre_alerta_paquete_id: pap.id).count
    assert_equal "Embolsar todo y quitar cajas",
                 Tarea.find_by(pre_alerta_paquete_id: pap.id).descripcion
  end

  test "borrar las instrucciones retira la tarea si nadie la completo" do
    pap = crear_pap(instrucciones: "Embolsar todo")
    assert_not_nil Tarea.find_by(pre_alerta_paquete_id: pap.id)

    pap.update!(instrucciones: "")

    assert_nil Tarea.find_by(pre_alerta_paquete_id: pap.id)
  end

  test "una tarea ya completada no se reabre ni se borra" do
    pap = crear_pap(instrucciones: "Embolsar todo")
    tarea = Tarea.find_by(pre_alerta_paquete_id: pap.id)
    tarea.completar!(users(:digitador))

    pap.update!(instrucciones: "Instrucciones nuevas")

    tarea.reload
    assert_predicate tarea, :realizada?, "no se debe reabrir trabajo ya hecho"
    assert_equal "Embolsar todo", tarea.descripcion
  end

  test "link_tracking! reapunta la tarea al paquete fisico" do
    pap = crear_pap(instrucciones: "Separar los items", tracking: "1Z999LINKTAREA1")
    tarea = Tarea.find_by(pre_alerta_paquete_id: pap.id)

    # El PAP ya trae un paquete "esperado"; lo desvinculamos para simular el
    # caso en que el paquete físico llega por separado.
    pap.update_columns(paquete_id: nil)
    tarea.update_columns(paquete_id: nil)

    paquete = paquetes(:recibido)
    PreAlertaPaquete.link_tracking!("1Z999LINKTAREA1", paquete)

    assert_equal paquete.id, tarea.reload.paquete_id
  end

  test "eliminar la linea de pre-alerta descarta la tarea abierta" do
    pap = crear_pap(instrucciones: "Embolsar todo")
    tarea_id = Tarea.find_by(pre_alerta_paquete_id: pap.id).id

    pap.destroy

    assert_nil Tarea.find_by(id: tarea_id)
  end

  test "eliminar la linea conserva la tarea ya completada" do
    pap = crear_pap(instrucciones: "Embolsar todo")
    tarea = Tarea.find_by(pre_alerta_paquete_id: pap.id)
    tarea.completar!(users(:digitador))

    pap.destroy

    tarea.reload
    assert_predicate tarea, :realizada?
    assert_nil tarea.pre_alerta_paquete_id, "queda como evidencia, ya sin la linea origen"
  end
end
