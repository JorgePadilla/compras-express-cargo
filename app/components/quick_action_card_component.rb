class QuickActionCardComponent < ViewComponent::Base
  ACCENTS = {
    teal: {
      icon_bg:  "bg-cec-teal-gradient",
      icon_fg:  "text-white",
      ring:     "hover:ring-cec-teal/40 dark:hover:ring-cec-teal-light/50",
      glow:     "group-hover:shadow-cec-teal-glow"
    },
    gold: {
      icon_bg:  "bg-cec-gold-gradient",
      icon_fg:  "text-white",
      ring:     "hover:ring-cec-gold/40 dark:hover:ring-cec-gold-light/50",
      glow:     "group-hover:shadow-cec-gold-glow"
    },
    navy: {
      icon_bg:  "bg-cec-navy-gradient",
      icon_fg:  "text-white",
      ring:     "hover:ring-cec-navy/40 dark:hover:ring-gray-300/40",
      glow:     "group-hover:shadow-cec-navy-glow"
    },
    red: {
      icon_bg:  "bg-cec-red-gradient",
      icon_fg:  "text-white",
      ring:     "hover:ring-red-300 dark:hover:ring-red-700/60",
      glow:     "group-hover:shadow-cec-red-glow"
    }
  }.freeze

  def initialize(title:, href:, icon:, subtitle: nil, accent: :teal)
    @title = title
    @href = href
    @icon = icon
    @subtitle = subtitle
    @accent = ACCENTS.key?(accent.to_sym) ? accent.to_sym : :teal
  end

  def palette
    ACCENTS[@accent]
  end
end
