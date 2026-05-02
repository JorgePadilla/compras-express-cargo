module DashboardHelper
  # Saludo dinámico segun la hora local del servidor (Time.zone).
  def greeting_for(time = Time.zone.now)
    h = time.hour
    if    h < 12 then "Buenos días"
    elsif h < 19 then "Buenas tardes"
    else              "Buenas noches"
    end
  end

  # Etiqueta legible y accent (teal/gold/red) para el chip de health status.
  # Devuelve [classes_dot, classes_chip, label].
  #
  # Diseño 2026-05-02: el chip vive sobre bg-cec-hero (gradient navy)
  # y los tints anteriores quedaban casi invisibles. Pasamos a fondo
  # SÓLIDO + texto contrastado + ring blanco translúcido + sombra de
  # color para profundidad. Yusef pidió mejor visibilidad/contraste.
  def health_chip(status)
    case status[:level]
    when :ok
      # cec-teal-dark + halo cec-teal — más sobrio y dentro de la
      # paleta CEC sin saltar al cyan vibrante.
      [ "bg-cec-teal-light", "bg-cec-teal-dark text-white ring-1 ring-cec-teal-light/40 shadow-md shadow-cec-teal/30", status[:message] ]
    when :warn
      [ "bg-cec-navy-dark",  "bg-cec-gold-dark text-white ring-1 ring-cec-gold-light/40 shadow-md shadow-cec-gold/30", status[:message] ]
    when :alert
      [ "bg-white",          "bg-red-600 text-white ring-1 ring-white/40 shadow-md shadow-red-500/40",   status[:message] ]
    else
      [ "bg-white",          "bg-gray-600 text-white ring-1 ring-white/30 shadow-md shadow-gray-700/30", status[:message].to_s ]
    end
  end

  # Calcula el delta porcentual today vs. yesterday. Devuelve un hash con:
  #   pct (Integer | nil — nil si yesterday == 0 y today == 0),
  #   direction (:up / :down / :flat / :new),
  #   label_short (e.g. "+12%" o "—" o "nuevo")
  def compute_delta(today, yesterday)
    today = today.to_f
    yesterday = yesterday.to_f
    if yesterday.zero?
      direction = today.zero? ? :flat : :new
      return { pct: nil, direction: direction, label_short: today.zero? ? "—" : "nuevo" }
    end
    delta = ((today - yesterday) / yesterday) * 100
    rounded = delta.round
    direction =
      if    rounded > 0 then :up
      elsif rounded < 0 then :down
      else                  :flat
      end
    sign = rounded.positive? ? "+" : ""
    { pct: rounded, direction: direction, label_short: "#{sign}#{rounded}%" }
  end

  # Color de un delta (positivo bueno por default — se puede invertir con
  # `inverse: true` cuando "menos es mejor", e.g. ventas pendientes).
  def delta_chip_classes(direction, inverse: false)
    good = inverse ? :down : :up
    bad  = inverse ? :up   : :down
    case direction
    when good
      "text-cec-teal-dark bg-cec-teal/10 dark:text-cec-teal-light dark:bg-cec-teal/20"
    when bad
      "text-red-700 bg-red-50 dark:text-red-200 dark:bg-red-900/30"
    when :new
      "text-cec-gold-dark bg-cec-gold/15 dark:text-cec-gold-light dark:bg-cec-gold/20"
    else
      "text-gray-600 bg-gray-100 dark:text-gray-300 dark:bg-gray-700"
    end
  end

  def delta_arrow(direction)
    case direction
    when :up    then "↑"
    when :down  then "↓"
    when :new   then "✦"
    else             "→"
    end
  end

  # Avatar gradient determinístico segun el nombre. Devuelve una clase CSS
  # ya definida en application.css.
  AVATAR_GRADIENTS = %w[avatar-gradient-navy avatar-gradient-teal avatar-gradient-gold].freeze

  def cliente_avatar_class(name)
    return AVATAR_GRADIENTS.first if name.blank?
    AVATAR_GRADIENTS[name.bytes.sum % AVATAR_GRADIENTS.length]
  end

  def cliente_initials(name, max: 2)
    return "?" if name.blank?
    parts = name.to_s.split(/\s+/).reject(&:blank?).first(max)
    parts.map { |p| p[0].to_s.upcase }.join.presence || "?"
  end

  # Construye una polyline SVG normalizada para sparklines. Recibe un array
  # de números y devuelve un string `x1,y1 x2,y2 ...` apto para `points=`.
  def sparkline_points(values, width: 80, height: 24, padding: 2)
    return "" if values.blank?
    max = values.max.to_f
    min = values.min.to_f
    range = (max - min).positive? ? (max - min) : 1.0
    last = values.length - 1
    last = 1 if last.zero? # evita divisón por 0 con un solo punto
    values.each_with_index.map do |v, i|
      x = padding + (i.to_f / last) * (width - padding * 2)
      y = height - padding - ((v - min) / range) * (height - padding * 2)
      "#{x.round(2)},#{y.round(2)}"
    end.join(" ")
  end
end
