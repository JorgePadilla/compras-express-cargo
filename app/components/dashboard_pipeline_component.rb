class DashboardPipelineComponent < ViewComponent::Base
  STAGES = [
    { key: :en_bodega,    label: "En bodega",        icon: "archive-box",        accent: :navy,  caption: "Recibidos + empacados" },
    { key: :en_transito,  label: "En tránsito",      icon: "paper-airplane",     accent: :gold,  caption: "Enviados + aduana" },
    { key: :disponibles,  label: "Listos entrega",   icon: "check-badge",        accent: :teal,  caption: "Disponibles en sucursal" },
    { key: :pendientes,   label: "Ventas pendientes", icon: "exclamation-circle", accent: :red,   caption: "Sin pago" }
  ].freeze

  ACCENTS = {
    navy: { bar: "bg-cec-navy",       chip: "bg-cec-navy-gradient text-white",  ring: "ring-cec-navy/20" },
    gold: { bar: "bg-cec-gold-dark",  chip: "bg-cec-gold-gradient text-white",  ring: "ring-cec-gold/30" },
    teal: { bar: "bg-cec-teal",       chip: "bg-cec-teal-gradient text-white",  ring: "ring-cec-teal/30" },
    red:  { bar: "bg-red-500",        chip: "bg-cec-red-gradient text-white",   ring: "ring-red-300/40" }
  }.freeze

  def initialize(en_bodega:, en_transito:, disponibles:, pendientes:)
    @counts = { en_bodega: en_bodega, en_transito: en_transito, disponibles: disponibles, pendientes: pendientes }
    @max = ([ en_bodega, en_transito, disponibles, pendientes, 1 ].compact.max).to_i
  end

  def stages
    STAGES.map do |stage|
      count = @counts[stage[:key]].to_i
      pct = ((count.to_f / @max) * 100).round
      stage.merge(count: count, pct: pct, accent_classes: ACCENTS[stage[:accent]])
    end
  end
end
