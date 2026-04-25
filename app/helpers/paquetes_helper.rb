module PaquetesHelper
  # Renders a sortable table header. Click toggles asc/desc; muestra ↑ / ↓
  # cuando es la columna activa.
  def sortable_header(column, label, css: "")
    current_sort = params[:sort].to_s
    current_dir  = params[:dir].to_s.downcase
    is_active = current_sort == column.to_s
    next_dir = is_active && current_dir == "asc" ? "desc" : "asc"

    arrow = if is_active
      content_tag(:span, current_dir == "asc" ? "↑" : "↓", class: "ml-1 text-cec-teal")
    else
      content_tag(:span, "↕", class: "ml-1 text-gray-300 dark:text-gray-600")
    end

    new_params = request.query_parameters.merge(sort: column, dir: next_dir, page: nil).reject { |_, v| v.nil? }
    link_to paquetes_path(new_params), class: "inline-flex items-center hover:text-cec-navy dark:hover:text-cec-gold #{css}" do
      concat label
      concat arrow
    end
  end

  def can_edit_paquetes?
    return false unless Current.user
    Current.user.admin? || PaquetesController::EDIT_ROLES.include?(Current.user.rol)
  end

  def can_delete_paquetes?
    return false unless Current.user
    Current.user.admin? || PaquetesController::DELETE_ROLES.include?(Current.user.rol)
  end
end
