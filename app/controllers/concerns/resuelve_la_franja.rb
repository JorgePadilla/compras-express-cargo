# Lo que la franja de contexto muestra para un cliente y un tracking: sus
# tareas abiertas y, si ya existe, el paquete de ese tracking.
#
# C17-02: vivía adentro de `PanelContextoController#show`, y `TareasController`
# lo necesita también para **re-pintar** la franja cuando se deja una tarea
# desde ahí. Con el tracking **fresco** del envío, no con el que tenía la
# franja al cargar: la bifurcación «postear al paquete o al cliente» del
# mini-form re-pintado no la puede corregir el JS después. Es el mismo tipo de
# estado viejo que mordió en `C16-05`.
module ResuelveLaFranja
  extend ActiveSupport::Concern

  private

  def tareas_de_la_franja(cliente)
    Tarea.abiertas
         .para_cliente(cliente.id)
         .visibles_para(Current.user)
         .includes(:asignado_a)
         .order(created_at: :asc)
  end

  # El paquete solo existe si el tracking ya fue recibido antes o si venía de
  # una pre-alerta (`crear_paquete_esperado`). Cuando no existe, la franja
  # muestra únicamente cliente + tareas + notas permanentes.
  def paquete_de_la_franja(cliente, tracking)
    return nil if tracking.blank?

    Paquete.where(cliente_id: cliente.id)
           .where("UPPER(tracking) = :t OR UPPER(tracking_secundario) = :t", t: tracking)
           .order(created_at: :desc)
           .first
  end
end
