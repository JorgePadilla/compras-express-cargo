module TareasHelper
  # PR-9.a: una tarea puede vivir bajo un paquete o directo bajo un cliente.
  # El "volver" y el "cancelar" del form apuntan a donde el usuario venía.
  def tareas_volver_path
    return paquete_tareas_path(@paquete) if @paquete
    return paquete_tareas_path(@tarea.paquete) if @tarea&.paquete
    return cliente_path(@tarea.cliente_id) if @tarea&.cliente_id.present?

    clientes_path
  end

  # C17-01: quién crea y quién gestiona tareas. Las listas viven en el
  # controller (`CREACION_ROLES`, `GESTION_ROLES`), igual que
  # `can_edit_clientes?` con la de clientes: una sola fuente para el guard y
  # para los botones. Hasta acá cada pantalla escribía su propia condición —o
  # ninguna—, y el digitador veía «Nueva tarea» para rebotar al clickear.
  def can_crear_tareas?
    return false unless Current.user

    Current.user.admin? || TareasController::CREACION_ROLES.include?(Current.user.rol)
  end

  def can_gestionar_tareas?
    return false unless Current.user

    Current.user.admin? || TareasController::GESTION_ROLES.include?(Current.user.rol)
  end
end
