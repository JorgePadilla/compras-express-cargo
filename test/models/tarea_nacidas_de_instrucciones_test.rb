require "test_helper"

# La limpieza de `PR-C7.41`: las tareas que `PR-9` fabricó desde las
# `instrucciones` del cliente. Solo se van las abiertas; las realizadas son
# evidencia de quién las marcó.
class TareaNacidasDeInstruccionesTest < ActiveSupport::TestCase
  setup do
    @cliente   = clientes(:juan)
    @abierta   = Tarea.create!(cliente: @cliente, titulo: "Instrucciones del cliente — 1Z1", origen: "pre_alerta")
    @realizada = Tarea.create!(cliente: @cliente, titulo: "Instrucciones del cliente — 1Z2", origen: "pre_alerta")
    @realizada.completar!(users(:digitador))
    @manual    = Tarea.create!(cliente: @cliente, titulo: "Llamar al cliente")
  end

  test "borra las abiertas nacidas de instrucciones y devuelve sus titulos" do
    borradas = Tarea.borrar_las_nacidas_de_instrucciones!

    assert_equal [ "Instrucciones del cliente — 1Z1" ], borradas
    assert_nil Tarea.find_by(id: @abierta.id)
  end

  test "la ya realizada se queda como evidencia" do
    Tarea.borrar_las_nacidas_de_instrucciones!

    @realizada.reload
    assert_predicate @realizada, :realizada?
    assert_equal users(:digitador), @realizada.completado_por
  end

  test "las manuales no se tocan, y correrlo dos veces no hace nada" do
    Tarea.borrar_las_nacidas_de_instrucciones!

    assert Tarea.exists?(@manual.id)
    assert_empty Tarea.borrar_las_nacidas_de_instrucciones!
  end
end
