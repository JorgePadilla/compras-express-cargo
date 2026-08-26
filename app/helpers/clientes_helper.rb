module ClientesHelper
  # C16-06: quién puede crear y editar clientes. La lista vive en el controller
  # (`EDICION_ROLES`), igual que `can_edit_paquetes?` con la de paquetes: una
  # sola fuente para el guard y para los botones.
  def can_edit_clientes?
    return false unless Current.user

    Current.user.admin? || ClientesController::EDICION_ROLES.include?(Current.user.rol)
  end
end
