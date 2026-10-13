module ClientesHelper
  # C16-06: quién puede crear y editar clientes. La lista vive en el controller
  # (`EDICION_ROLES`), igual que `can_edit_paquetes?` con la de paquetes: una
  # sola fuente para el guard y para los botones.
  def can_edit_clientes?
    return false unless Current.user

    Current.user.admin? || Current.user.tiene_rol?(ClientesController::EDICION_ROLES)
  end

  # PR-C31.11 · En la vista del cliente cada fila lleva al registro **si quien
  # mira puede abrirlo**. SAC ve las facturas del cliente —Yusef: *"todas las
  # facturas"*— pero no entra a /ventas: ahí el número va sin link, en vez de un
  # link que termina en «No tienes permiso».
  def enlace_del_cliente(texto, ruta, seccion)
    clases = "text-sm font-mono font-medium"
    if can_access?(seccion)
      link_to texto, ruta, class: "#{clases} text-cec-navy dark:text-cec-gold hover:underline"
    else
      content_tag :span, texto, class: "#{clases} text-gray-700 dark:text-gray-200"
    end
  end
end
