require "test_helper"

# C17-02: la tarea que se dejó desde la franja con el tracking en pantalla pasa
# a colgar del paquete cuando el paquete se guarda.
class TareaAtarAlPaqueteTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @paquete = paquetes(:recibido)
  end

  def tarea_pendiente(tracking, cliente: @cliente)
    Tarea.create!(cliente: cliente, titulo: "Revisar", tracking: tracking)
  end

  test "ata por el tracking" do
    tarea = tarea_pendiente(@paquete.tracking.downcase)

    assert_equal 1, Tarea.atar_al_paquete!(@paquete)
    assert_equal @paquete.id, tarea.reload.paquete_id
  end

  test "ata tambien por el secundario, que es donde queda lo escaneado en el caso USPS" do
    @paquete.update!(tracking_secundario: "9400SECUNDARIO0001")
    tarea = tarea_pendiente("9400SECUNDARIO0001")

    Tarea.atar_al_paquete!(@paquete)

    assert_equal @paquete.id, tarea.reload.paquete_id
  end

  test "no toca las de otro cliente ni las que ya tienen paquete" do
    de_otro = tarea_pendiente(@paquete.tracking, cliente: clientes(:maria))
    ya_atada = Tarea.create!(paquete: paquetes(:disponible_entrega_juan), titulo: "x", tracking: @paquete.tracking)

    Tarea.atar_al_paquete!(@paquete)

    assert_nil de_otro.reload.paquete_id
    assert_equal paquetes(:disponible_entrega_juan).id, ya_atada.reload.paquete_id
  end

  test "sin tracking no hay nada que atar" do
    sin_tracking = Tarea.create!(cliente: @cliente, titulo: "Suelta")

    assert_equal 0, Tarea.atar_al_paquete!(@paquete)
    assert_nil sin_tracking.reload.paquete_id
  end
end
