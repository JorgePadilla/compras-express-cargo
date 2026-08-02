module TareasHelper
  # PR-9.a: una tarea puede vivir bajo un paquete o directo bajo un cliente.
  # El "volver" y el "cancelar" del form apuntan a donde el usuario venía.
  def tareas_volver_path
    return paquete_tareas_path(@paquete) if @paquete
    return cliente_path(@tarea.cliente_id) if @tarea&.cliente_id.present?

    clientes_path
  end
end
