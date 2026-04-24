class DashboardController < ApplicationController
  DASHBOARD_ROLES = %w[admin supervisor_miami supervisor_caja supervisor_prefactura].freeze

  before_action :redirect_cliente_to_portal
  before_action :require_dashboard_access

  def index
    metrics = DashboardMetrics.new.to_h
    metrics.each { |key, value| instance_variable_set("@#{key}", value) }
  end

  private

  # Si hay una sesión de cliente activa, redirige al portal de cuenta antes
  # de procesar la vista de dashboard admin. Evita exponer la UI admin a un
  # cliente y mantiene la separación de contextos.
  def redirect_cliente_to_portal
    return unless cookies.signed[:cliente_session_id]
    return unless ClienteSession.exists?(id: cookies.signed[:cliente_session_id])

    redirect_to cuenta_root_path
  end

  # Requiere que el usuario autenticado tenga un rol con acceso al dashboard
  # admin (admin + supervisores). Otros roles son redirigidos a su sección
  # apropiada.
  def require_dashboard_access
    return if Current.user&.admin?
    return if DASHBOARD_ROLES.include?(Current.user&.rol)

    fallback = case Current.user&.rol
               when "cajero"           then caja_path
               when "digitador_miami"  then etiquetar_path
               when "entrega_despacho" then entregas_path
               when "sac"              then paquetes_path
               else new_session_path
               end

    redirect_to fallback, alert: "No tienes permiso para acceder al dashboard."
  end
end
