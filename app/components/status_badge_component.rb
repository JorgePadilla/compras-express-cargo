class StatusBadgeComponent < ViewComponent::Base
  # 5 semantic families — labels distinguish sub-states within each family.
  # Cada familia incluye variantes dark: explicitas para mantener contraste
  # AA en dark mode (los colores -dark de marca quedan ilegibles sobre el
  # fondo oscuro; usamos las variantes -light + bg de mayor opacidad).
  SUCCESS = "bg-cec-teal/10 text-cec-teal-dark ring-1 ring-cec-teal/30 dark:bg-cec-teal/25 dark:text-cec-teal-light dark:ring-cec-teal/50".freeze
  INFO    = "bg-cec-navy/5  text-cec-navy      ring-1 ring-cec-navy/20 dark:bg-cec-navy/40 dark:text-gray-100      dark:ring-cec-navy/60".freeze
  WARNING = "bg-cec-gold/10 text-cec-gold-dark ring-1 ring-cec-gold/30 dark:bg-cec-gold/20 dark:text-cec-gold-light dark:ring-cec-gold/50".freeze
  DANGER  = "bg-red-50      text-red-700       ring-1 ring-red-600/20  dark:bg-red-900/40  dark:text-red-200       dark:ring-red-500/50".freeze
  NEUTRAL = "bg-slate-100   text-slate-600     ring-1 ring-slate-500/20 dark:bg-slate-700  dark:text-slate-200     dark:ring-slate-500/40".freeze

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
    "consolidando_honduras" => INFO, "recoleta_en_proceso" => INFO,
    # A7-09/A7-10
    "consolidando_miami" => INFO, "enviado_sucursal" => INFO,

    # Warning — pending / held / awaiting action
    "pendiente" => WARNING, "pre_alerta" => WARNING,
    # `pre_alerta` es el estado de `PreAlerta`; `pre_alerta_estado` es el del
    # `Paquete` esperado, y faltaba: se pintaba gris por fallback pese a ser
    # exactamente lo mismo para quien lo mira.
    "pre_alerta_estado" => WARNING,
    "retenido" => WARNING, "en_aduana" => WARNING,

    # Danger
    "anulado" => DANGER, "retornado" => DANGER, "desechado" => DANGER,
    "extraviado" => DANGER, "devuelto" => DANGER,

    # Neutral
    "inactivo" => NEUTRAL, "retiro_oficina" => NEUTRAL
  }.freeze

  # `title:` es para cuando el rótulo visible va abreviado — la tabla de
  # `/paquetes` usa el corto para no comerse el ancho del tracking, y deja el
  # largo debajo del mouse. Sin él, un `REC MIAMI` sería una sigla y nada más.
  def initialize(status:, label: nil, title: nil)
    @status = status.to_s
    @label = label || @status.humanize
    @title = title
  end

  def call
    content_tag :span, @label,
      title: @title,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_classes}"
  end

  private

  def color_classes
    COLORS[@status] || NEUTRAL
  end
end
