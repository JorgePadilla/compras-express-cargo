require "test_helper"

class TareaTest < ActiveSupport::TestCase
  test "estado por defecto es pendiente" do
    t = Tarea.new(paquete: paquetes(:recibido), titulo: "Inspeccion")
    assert_predicate t, :pendiente?
  end

  test "valida presencia de titulo y estado" do
    t = Tarea.new(paquete: paquetes(:recibido))
    assert_not t.valid?
    assert_includes t.errors[:titulo], "no puede estar en blanco"
  end

  test "completar! marca como realizada y registra usuario" do
    t = tareas(:en_proceso_recibido)
    user = users(:digitador)

    t.completar!(user)

    assert_predicate t.reload, :realizada?
    assert_equal user, t.completado_por
    assert_not_nil t.completada_en
  end

  test "reabrir! vuelve a pendiente y limpia completado" do
    t = tareas(:realizada_disponible)
    t.reabrir!

    t.reload
    assert_predicate t, :pendiente?
    assert_nil t.completado_por
    assert_nil t.completada_en
  end

  test "iniciar! cambia a en_proceso" do
    t = tareas(:pendiente_recibido)
    user = users(:digitador)

    t.iniciar!(user)

    assert_predicate t.reload, :en_proceso?
    assert_equal user, t.asignado_a
  end

  test "scope abiertas excluye realizadas" do
    abiertas = Tarea.abiertas
    assert_includes abiertas, tareas(:pendiente_recibido)
    assert_includes abiertas, tareas(:en_proceso_recibido)
    assert_not_includes abiertas, tareas(:realizada_disponible)
  end

  test "paquete.tareas_pendientes? refleja tareas no realizadas" do
    paquete = paquetes(:recibido)
    assert paquete.tareas_pendientes?, "esperaba tareas abiertas por la fixture"

    paquete.tareas.abiertas.find_each { |t| t.completar!(users(:digitador)) }

    paquete.reload
    assert_not paquete.tareas_pendientes?
  end

  test "paquete sin tareas no esta bloqueado" do
    paquete = paquetes(:disponible_entrega_maria)
    paquete.tareas.destroy_all
    assert_not paquete.tareas_pendientes?
  end

  test "paquete no avanza de estado si tiene tareas abiertas" do
    paquete = paquetes(:recibido) # estado recibido_miami
    paquete.tareas.destroy_all
    paquete.tareas.create!(titulo: "Revisar")

    paquete.estado = "empacado"
    assert_not paquete.save
    assert_includes paquete.errors[:estado].join, "tareas pendientes"
  end

  test "paquete avanza de estado cuando todas las tareas estan realizadas" do
    paquete = paquetes(:recibido)
    paquete.tareas.destroy_all
    tarea = paquete.tareas.create!(titulo: "Revisar")
    tarea.completar!(users(:digitador))

    paquete.estado = "empacado"
    assert paquete.save
  end

  test "paquete puede cambiar a estado terminal aunque tenga tareas abiertas" do
    paquete = paquetes(:recibido)
    paquete.tareas.destroy_all
    paquete.tareas.create!(titulo: "Revisar")

    # anular es terminal, no parte del orden de progresion
    paquete.estado = "anulado"
    assert paquete.save
  end
end
