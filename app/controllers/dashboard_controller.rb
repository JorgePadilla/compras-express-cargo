class DashboardController < ApplicationController
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

    # ── Serie 7 dias: paquetes recibidos por dia ──
    @paquetes_7_dias = (0..6).map do |i|
      day = today - i
      {
        fecha: day,
        label: day.strftime("%a %d"),
        paquetes: Paquete.where(fecha_recibido_miami: day.all_day).count
      }
    end.reverse

    # ── Actividad reciente ──
    @paquetes_recientes = Paquete.includes(:cliente).order(created_at: :desc).limit(8)
    @ventas_recientes   = Venta.includes(:cliente).order(created_at: :desc).limit(5)
  end
end
