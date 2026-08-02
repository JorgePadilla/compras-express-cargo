# Presentación de los tipos de envío (iconografía + significado).
# Fuente única de verdad compartida entre el wizard de pre-alerta del cliente
# (cuenta/pre_alertas/new) y el selector de sesión de /etiquetar. Antes esto
# estaba hardcodeado inline en el view de pre-alerta.
module TipoEnvioPresentationHelper
  # Descripciones canónicas v4 (one-liners por pre_alerta_v4.docx), por código.
  DESCRIPCIONES = {
    "express" => "Aéreo express — sale los viernes. El más rápido.",
    "cer"     => "Aéreo estándar. Balance entre precio y tiempo.",
    "cem"     => "Marítimo. La opción más económica con reempaque.",
    "cka"     => "Aéreo sin reempaque. Tu caja llega tal como la enviaste.",
    "ckm"     => "Marítimo sin reempaque. Económico y sin manipulación."
  }.freeze

  def tipo_envio_descripcion(tipo)
    DESCRIPCIONES[tipo.codigo.to_s.downcase]
  end

  # Color de acento por código de servicio. `text`/`icon_bg` los usan las
  # tarjetas; `bg`/`ring` el banner de sesión activa de /etiquetar.
  def tipo_envio_accent(tipo)
    case tipo.codigo.to_s.downcase
    when "express" then { text: "text-cec-gold", icon_bg: "bg-cec-gold/15", bg: "bg-cec-gold/10", ring: "ring-cec-gold/40" }
    when "cer"     then { text: "text-cec-teal", icon_bg: "bg-cec-teal/15", bg: "bg-cec-teal/10", ring: "ring-cec-teal/40" }
    when "cem"     then { text: "text-cec-navy", icon_bg: "bg-cec-navy/10", bg: "bg-cec-navy/10", ring: "ring-cec-navy/30" }
    else                { text: "text-slate-600", icon_bg: "bg-slate-100", bg: "bg-slate-100", ring: "ring-slate-300" }
    end
  end

  # Ícono heroicon según modalidad: marítimo → camión, aéreo → avión.
  def tipo_envio_icono(tipo)
    tipo.modalidad == "maritimo" ? "truck" : "paper-airplane"
  end
end
