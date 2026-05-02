class DashboardHeroComponent < ViewComponent::Base
  def initialize(user:, health_status:, signals: {}, time: Time.zone.now)
    @user = user
    @health_status = health_status || { level: :ok, message: "Operación saludable" }
    @signals = signals || {}
    @time = time
  end

  def display_name
    @user.respond_to?(:nombre) && @user.nombre.present? ? @user.nombre.split.first : @user.email_address
  end

  def long_date
    formatted = I18n.l(@time.to_date, format: "%A %-d de %B")
    formatted.sub(/^./, &:upcase)
  end

  # Mini-stats que se muestran debajo del status header. Cada uno con
  # value, label, href (opcional click-through) e icono. El tone varía
  # según thresholds (ok/warn/alert) para que el número cambie de color
  # cuando cruza un umbral operativo. Yusef 2026-05-02: pidió análisis
  # más profundo de la operación en el espacio del chip.
  def mini_stats
    [
      stat(:ventas_pendientes,    "Ventas pendientes", helpers.ventas_path(estado: "pendiente"),
           "currency-dollar",            warn_above: 10, alert_above: 20),
      stat(:tareas_abiertas,      "Tareas abiertas",   nil,
           "clipboard-document-check",   warn_above: 12, alert_above: 25),
      stat(:paquetes_disponibles, "Paq. disponibles",  helpers.paquetes_path(estados: [ "disponible_entrega" ]),
           "archive-box"),
      stat(:entregas_en_reparto,  "En reparto",        helpers.entregas_path(estado: "en_reparto"),
           "truck")
    ].compact
  end

  private

  def stat(key, label, href, icon, warn_above: nil, alert_above: nil)
    value = @signals[key]
    return nil if value.nil?
    tone = if alert_above && value >= alert_above then :alert
    elsif warn_above && value >= warn_above       then :warn
    else                                                :ok
    end
    { key: key, label: label, value: value, href: href, icon: icon, tone: tone }
  end
end
