class DashboardKpiCardComponent < ViewComponent::Base
  ACCENTS = {
    teal: {
      icon_bg:  "bg-cec-teal-gradient",
      glow:     "hover:shadow-cec-teal-glow",
      stroke:   "var(--color-cec-teal-dark)",
      fill:     "var(--color-cec-teal)",
      ring:     "ring-cec-teal/30"
    },
    gold: {
      icon_bg:  "bg-cec-gold-gradient",
      glow:     "hover:shadow-cec-gold-glow",
      stroke:   "var(--color-cec-gold-dark)",
      fill:     "var(--color-cec-gold)",
      ring:     "ring-cec-gold/30"
    },
    navy: {
      icon_bg:  "bg-cec-navy-gradient",
      glow:     "hover:shadow-cec-navy-glow",
      stroke:   "var(--color-cec-navy)",
      fill:     "var(--color-cec-navy-light)",
      ring:     "ring-cec-navy/30"
    }
  }.freeze

  # title:    String (e.g. "Ingresos hoy")
  # value:    Number  (target del count-up)
  # decimals: Integer
  # prefix/suffix: para count-up (e.g. "L ")
  # icon:     heroicon name
  # accent:   :teal / :gold / :navy
  # delta:    hash from DashboardHelper#compute_delta
  # series:   array of numbers (sparkline)
  # caption:  texto secundario opcional ("Semana: …")
  # inverse_delta: si true, una bajada se considera buena (para "ventas pendientes")
  def initialize(title:, value:, icon:, accent:, delta:, series: [], decimals: 0, prefix: "", suffix: "", caption: nil, inverse_delta: false)
    @title = title
    @value = value.to_f
    @decimals = decimals
    @prefix = prefix
    @suffix = suffix
    @icon = icon
    @accent = ACCENTS.key?(accent.to_sym) ? accent.to_sym : :teal
    @delta = delta || { pct: nil, direction: :flat, label_short: "—" }
    @series = series.to_a
    @caption = caption
    @inverse_delta = inverse_delta
  end

  def palette
    ACCENTS[@accent]
  end

  def sparkline_d
    return nil if @series.length < 2
    helpers.sparkline_points(@series)
  end

  def delta_classes
    helpers.delta_chip_classes(@delta[:direction], inverse: @inverse_delta)
  end

  def delta_arrow
    helpers.delta_arrow(@delta[:direction])
  end

  attr_reader :title, :value, :decimals, :prefix, :suffix, :icon, :delta, :caption
end
