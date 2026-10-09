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

    Current.user.admin? || Current.user.tiene_rol?(TareasController::CREACION_ROLES)
  end

  def can_gestionar_tareas?
    return false unless Current.user

    Current.user.admin? || Current.user.tiene_rol?(TareasController::GESTION_ROLES)
  end

  # El área de una tarea nueva: la del que la crea. Para admin, ninguna
  # («todas las áreas»). Lo usan `/tareas/new` y el mini-form de la franja.
  def departamento_por_defecto_de(user)
    return nil if user.nil? || user.admin?

    # El principal a propósito: una tarea nueva cae en **un** área, y con dos
    # roles hay que elegir una. La del puesto que la persona tiene como
    # principal es la menos sorprendente — y el campo se puede cambiar a mano.
    Tarea::DEPARTAMENTOS_POR_ROL[user.rol]&.first
  end
end
