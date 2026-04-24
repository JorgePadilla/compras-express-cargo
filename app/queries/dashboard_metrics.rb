# Centraliza todas las lecturas del dashboard admin para que sean fáciles de
# auditar y que el controller quede slim. Cada método ejecuta exactamente una
# query agregada (`SUM` / `COUNT` / `GROUP BY`). La actividad reciente usa
# `includes(:cliente)` para evitar N+1 en la vista.
class DashboardMetrics
  def initialize(today: Time.zone.now.to_date)
    @today = today
    @week_start = today.beginning_of_week
    @month_start = today.beginning_of_month
  end

  def to_h
    {
      # KPIs del día
      ingresos_hoy: pagos_hoy.sum(:monto),
      entregas_hoy: Entrega.where(entregado_at: @today.all_day).count,
      paquetes_recibidos_hoy: paquetes_hoy.count,
      pre_alertas_hoy: PreAlerta.where(created_at: @today.all_day).count,

      # Semana / mes
      ingresos_semana: Pago.completados
                           .where(created_at: @week_start.beginning_of_day..@today.end_of_day)
                           .sum(:monto),
      paquetes_semana: Paquete
                         .where(fecha_recibido_miami: @week_start.beginning_of_day..@today.end_of_day)
                         .count,
      ingresos_mes:    Pago.completados
                           .where(created_at: @month_start.beginning_of_day..@today.end_of_day)
                           .sum(:monto),
      paquetes_mes:    Paquete
                         .where(fecha_recibido_miami: @month_start.beginning_of_day..@today.end_of_day)
                         .count,

      # Pipeline operativo
      paquetes_en_bodega:   Paquete.where(estado: %w[recibido_miami empacado]).count,
      paquetes_en_transito: Paquete.where(estado: %w[enviado_honduras en_aduana]).count,
      paquetes_disponibles: Paquete.where(estado: "disponible_entrega").count,
      entregas_en_reparto:  Entrega.where(estado: "en_reparto").count,
      ventas_pendientes:    Venta.where(estado: "pendiente").count,
      tareas_abiertas:      Tarea.abiertas.count,

      # Serie 7 días (1 sola query GROUP BY DATE)
      paquetes_7_dias: paquetes_7_dias,

      # Actividad reciente (preloaded)
      paquetes_recientes: Paquete.includes(:cliente).order(created_at: :desc).limit(8),
      ventas_recientes:   Venta.includes(:cliente).order(created_at: :desc).limit(5)
    }
  end

  private

  def pagos_hoy
    Pago.completados.where(created_at: @today.all_day)
  end

  def paquetes_hoy
    Paquete.where(fecha_recibido_miami: @today.all_day)
  end

  def paquetes_7_dias
    range_start = (@today - 6).beginning_of_day
    counts = Paquete
               .where(fecha_recibido_miami: range_start..@today.end_of_day)
               .group("DATE(fecha_recibido_miami)")
               .count
               .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k.to_date }

    (0..6).map do |i|
      day = @today - i
      { fecha: day, label: day.strftime("%a %d"), paquetes: counts[day] || 0 }
    end.reverse
  end
end
