class StatusBadgeComponent < ViewComponent::Base
  # 5 semantic families — labels distinguish sub-states within each family.
  SUCCESS = "bg-cec-teal/10 text-cec-teal-dark ring-1 ring-cec-teal/30".freeze
  INFO    = "bg-cec-navy/5  text-cec-navy      ring-1 ring-cec-navy/20".freeze
  WARNING = "bg-cec-gold/10 text-cec-gold-dark ring-1 ring-cec-gold/30".freeze
  DANGER  = "bg-red-50      text-red-700       ring-1 ring-red-600/20".freeze
  NEUTRAL = "bg-slate-100   text-slate-600     ring-1 ring-slate-500/20".freeze

  COLORS = {
    # Success — positive end-states
    "activo" => SUCCESS, "disponible" => SUCCESS, "disponible_entrega" => SUCCESS,
    "entregado" => SUCCESS, "pagado" => SUCCESS, "facturado" => SUCCESS,
    "abierta" => SUCCESS, "cerrada" => NEUTRAL, "completado" => SUCCESS,

    # Info — in-progress logistics states
    "recibido_miami" => INFO, "empacado" => INFO, "enviado_honduras" => INFO,
    "en_reparto" => INFO, "pre_facturado" => INFO, "creado" => INFO, "domicilio" => INFO,
    "en_proceso" => INFO, "en_miami" => INFO, "en_transito" => INFO,
    "recibido" => INFO, "enviado" => INFO,

    # Warning — pending / held / awaiting action
    "pendiente" => WARNING, "pre_alerta" => WARNING,
    "retenido" => WARNING, "en_aduana" => WARNING,

    # Danger
    "anulado" => DANGER, "retornado" => DANGER, "desechado" => DANGER,
    "extraviado" => DANGER, "devuelto" => DANGER,

    # Neutral
    "inactivo" => NEUTRAL, "retiro_oficina" => NEUTRAL
  }.freeze

  def initialize(status:, label: nil)
    @status = status.to_s
    @label = label || @status.humanize
  end

  def call
    content_tag :span, @label,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_classes}"
  end

  private

  def color_classes
    COLORS[@status] || NEUTRAL
  end
end
