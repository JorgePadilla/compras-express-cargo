# Centraliza todas las lecturas del dashboard admin para que sean fáciles de
# auditar y que el controller quede slim. Cada método ejecuta una query
# agregada (`SUM` / `COUNT` / `GROUP BY`). La actividad reciente usa
# `includes(:cliente)` para evitar N+1 en la vista.
class DashboardMetrics
  def initialize(today: Time.zone.now.to_date)
    @today = today
    @yesterday = today - 1
    @week_start = today.beginning_of_week
    @month_start = today.beginning_of_month
  end

  def to_h
    ingresos_hoy_val           = pagos_hoy.sum(:monto)
    entregas_hoy_val           = Entrega.where(entregado_at: @today.all_day).count
    paquetes_recibidos_hoy_val = paquetes_hoy.count
    pre_alertas_hoy_val        = PreAlerta.where(created_at: @today.all_day).count

    ingresos_ayer_val           = Pago.completados.where(created_at: @yesterday.all_day).sum(:monto)
    entregas_ayer_val           = Entrega.where(entregado_at: @yesterday.all_day).count
    paquetes_recibidos_ayer_val = Paquete.where(fecha_recibido_miami: @yesterday.all_day).count
    pre_alertas_ayer_val        = PreAlerta.where(created_at: @yesterday.all_day).count

    ventas_pendientes_val = Venta.where(estado: "pendiente").count
    tareas_abiertas_val   = Tarea.abiertas.count

    {
      # KPIs del día
      ingresos_hoy: ingresos_hoy_val,
      entregas_hoy: entregas_hoy_val,
      paquetes_recibidos_hoy: paquetes_recibidos_hoy_val,
      pre_alertas_hoy: pre_alertas_hoy_val,

      # KPIs ayer (para deltas)
      ingresos_ayer: ingresos_ayer_val,
      entregas_ayer: entregas_ayer_val,
      paquetes_recibidos_ayer: paquetes_recibidos_ayer_val,
      pre_alertas_ayer: pre_alertas_ayer_val,

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
      ventas_pendientes:    ventas_pendientes_val,
      tareas_abiertas:      tareas_abiertas_val,

      # Series 7 días — para chart principal y sparklines de KPIs
      paquetes_7_dias:    paquetes_7_dias,
      ingresos_7_dias:    ingresos_7_dias,
      entregas_7_dias:    entregas_7_dias,
      pre_alertas_7_dias: pre_alertas_7_dias,

      # Estado de salud (heurística simple sobre signos vitales del día)
      health_status: health_status(
        ventas_pendientes: ventas_pendientes_val,
        tareas_abiertas: tareas_abiertas_val
      ),

      # Actividad reciente (preloaded)
      paquetes_recientes: Paquete.includes(:cliente, :sucursal, :sucursal_destino).order(created_at: :desc).limit(8),
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
    series_for_dates(
      Paquete.where(fecha_recibido_miami: range_7d).group("DATE(fecha_recibido_miami)").count,
      key: :paquetes
    )
  end

  def ingresos_7_dias
    raw = Pago.completados.where(created_at: range_7d).group("DATE(created_at)").sum(:monto)
    series_for_dates(raw.transform_values(&:to_f), key: :total)
  end

  def entregas_7_dias
    series_for_dates(
      Entrega.where(entregado_at: range_7d).group("DATE(entregado_at)").count,
      key: :total
    )
  end

  def pre_alertas_7_dias
    series_for_dates(
      PreAlerta.where(created_at: range_7d).group("DATE(created_at)").count,
      key: :total
    )
  end

  def range_7d
    (@today - 6).beginning_of_day..@today.end_of_day
  end

  # Convierte un hash {date_string => count} a array ordenado de los últimos 7
  # días con `{ fecha:, label:, <key>: }`. Llena ceros donde no hay datos.
  def series_for_dates(raw_counts, key:)
    counts = raw_counts.transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k.to_date }
    (0..6).map do |i|
      day = @today - i
      { fecha: day, label: day.strftime("%a %d"), key => counts[day] || 0 }
    end.reverse
  end

  # Heurística simple: define un estado operativo agregado del día.
  #  - :alert  si ventas_pendientes ≥ 20 o tareas_abiertas ≥ 25
  #  - :warn   si ventas_pendientes ≥ 10 o tareas_abiertas ≥ 12
  #  - :ok     resto
  # Esto es un primer cut — los thresholds se pueden tunear con uso real.
  def health_status(ventas_pendientes:, tareas_abiertas:)
    if ventas_pendientes >= 20 || tareas_abiertas >= 25
      { level: :alert, message: pluralized_alert(ventas_pendientes, tareas_abiertas) }
    elsif ventas_pendientes >= 10 || tareas_abiertas >= 12
      { level: :warn, message: pluralized_warn(ventas_pendientes, tareas_abiertas) }
    else
      { level: :ok, message: "Operación saludable" }
    end
  end

  def pluralized_warn(ventas, tareas)
    parts = []
    parts << "#{ventas} ventas pendientes" if ventas >= 10
    parts << "#{tareas} tareas abiertas"   if tareas >= 12
    "Atención: #{parts.join(' · ')}"
  end

  def pluralized_alert(ventas, tareas)
    parts = []
    parts << "#{ventas} ventas pendientes" if ventas >= 20
    parts << "#{tareas} tareas abiertas"   if tareas >= 25
    "Crítico: #{parts.join(' · ')}"
  end
end
