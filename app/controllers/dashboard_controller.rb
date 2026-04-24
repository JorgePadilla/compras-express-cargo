class DashboardController < ApplicationController
  before_action :redirect_cliente_to_portal

  def index
    today = Time.zone.now.to_date
    week_start = today.beginning_of_week
    month_start = today.beginning_of_month

    # ── KPIs "hoy" ──
    @ingresos_hoy    = Pago.completados.where(created_at: today.all_day).sum(:monto)
    @entregas_hoy    = Entrega.where(entregado_at: today.all_day).count
    @paquetes_recibidos_hoy = Paquete.where(fecha_recibido_miami: today.all_day).count
    @pre_alertas_hoy = PreAlerta.where(created_at: today.all_day).count

    # ── KPIs de la semana ──
    @ingresos_semana = Pago.completados.where(created_at: week_start.beginning_of_day..today.end_of_day).sum(:monto)
    @paquetes_semana = Paquete.where(fecha_recibido_miami: week_start.beginning_of_day..today.end_of_day).count

    # ── KPIs del mes ──
    @ingresos_mes    = Pago.completados.where(created_at: month_start.beginning_of_day..today.end_of_day).sum(:monto)
    @paquetes_mes    = Paquete.where(fecha_recibido_miami: month_start.beginning_of_day..today.end_of_day).count

    # ── Pendientes / en proceso ──
    @paquetes_en_bodega    = Paquete.where(estado: %w[recibido_miami empacado]).count
    @paquetes_en_transito  = Paquete.where(estado: %w[enviado_honduras en_aduana]).count
    @paquetes_disponibles  = Paquete.where(estado: "disponible_entrega").count
    @entregas_en_reparto   = Entrega.where(estado: "en_reparto").count
    @ventas_pendientes     = Venta.where(estado: "pendiente").count
    @tareas_abiertas       = Tarea.abiertas.count

    # ── Serie 7 días: 1 sola query agrupada por día (antes eran 7 COUNT) ──
    range_start = (today - 6).beginning_of_day
    counts_by_day = Paquete
                      .where(fecha_recibido_miami: range_start..today.end_of_day)
                      .group("DATE(fecha_recibido_miami)")
                      .count
                      .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k.to_date }

    @paquetes_7_dias = (0..6).map do |i|
      day = today - i
      { fecha: day, label: day.strftime("%a %d"), paquetes: counts_by_day[day] || 0 }
    end.reverse

    # ── Actividad reciente (eager load cliente para evitar N+1) ──
    @paquetes_recientes = Paquete.includes(:cliente).order(created_at: :desc).limit(8)
    @ventas_recientes   = Venta.includes(:cliente).order(created_at: :desc).limit(5)
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
end
