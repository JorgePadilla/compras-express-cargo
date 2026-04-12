module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :admin?, :can_access?
  end

  private

  def require_admin
    require_role # no roles passed → only admin? guard passes
  end

  def require_role(*roles)
    return if Current.user&.admin?

    unless roles.map(&:to_s).include?(Current.user&.rol)
      redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion."
    end
  end

  def require_location(*locations)
    return if Current.user&.admin?

    unless locations.map(&:to_s).include?(Current.user&.ubicacion)
      redirect_to root_path, alert: "Esta seccion no esta disponible en tu ubicacion."
    end
  end

  def admin?
    Current.user&.admin?
  end

  def can_access?(feature)
    return true if admin?

    role = Current.user&.rol
    case feature
    when :etiquetar, :manifiestos
      role.in?(%w[supervisor_miami digitador_miami])
    when :pre_facturas
      role.in?(%w[supervisor_prefactura supervisor_caja cajero])
    when :caja, :ventas, :recibos
      role.in?(%w[supervisor_caja cajero])
    when :notas_debito
      role.in?(%w[supervisor_caja supervisor_prefactura cajero])
    when :notas_credito
      role.in?(%w[supervisor_caja])
    when :empresa_settings
      false
    when :entregas
      role.in?(%w[entrega_despacho supervisor_caja])
    when :clientes, :pre_alertas, :paquetes
      true
    when :usuarios, :configuraciones, :reportes, :empleados
      false
    when :marketing
      role.in?(%w[sac])
    else
      false
    end
  end
end
