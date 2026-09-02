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

  # ── El color agrupa, el ícono identifica ────────────────────────────────
  #
  # Jorge, mirando el selector: *"veo varios iconos repetidos para tipos de
  # envío… hay muchos iconos, me parece que podemos variar"*.
  #
  # Tenía razón y era peor de lo que se ve: el ícono se elegía **solo por
  # modalidad**, así que con cinco servicios quedaban tres aviones idénticos y
  # dos camiones idénticos. Y `cka`/`ckm` caían las dos al gris del `else`, o
  # sea que además compartían el color: dos tarjetas exactamente iguales.
  #
  # El ícono no puede cargar dos ejes a la vez (modalidad × reempaque) con
  # cinco servicios. Así que se reparte: **el ícono identifica al servicio y el
  # color dice la modalidad** —aéreo en teal, marítimo en navy, y el dorado de
  # Express marcando que es el rápido—. La modalidad además ya está escrita en
  # la descripción de la tarjeta («Aéreo…», «Marítimo…»), así que no depende
  # solo del color.
  def tipo_envio_accent(tipo)
    case tipo.codigo.to_s.downcase
    when "express"     then { text: "text-cec-gold", icon_bg: "bg-cec-gold/15", bg: "bg-cec-gold/10", ring: "ring-cec-gold/40" }
    when "cer", "cka"  then { text: "text-cec-teal", icon_bg: "bg-cec-teal/15", bg: "bg-cec-teal/10", ring: "ring-cec-teal/40" }
    when "cem", "ckm"  then { text: "text-cec-navy", icon_bg: "bg-cec-navy/10", bg: "bg-cec-navy/10", ring: "ring-cec-navy/30" }
    else                    { text: "text-slate-600", icon_bg: "bg-slate-100", bg: "bg-slate-100", ring: "ring-slate-300" }
    end
  end

  # Uno por servicio. `:barco` no es un heroicon —el set no trae ninguno— y lo
  # dibuja `shared/_icono_barco`; ver `icono_de_tipo_envio`.
  ICONOS = {
    "express" => "bolt",            # el más rápido, sale los viernes
    "cer"     => "paper-airplane",  # el aéreo de todos los días
    "cka"     => "cube",            # aéreo sin reempaque: la caja llega tal cual
    "cem"     => :barco,            # marítimo
    "ckm"     => "archive-box"      # marítimo sin reempaque
  }.freeze

  # Con `codigo` desconocido —los `*-legacy` que la seed limpia, o un servicio
  # que alguien cree mañana desde /servicios— se cae a la modalidad, que es lo
  # único que se puede saber sin conocer el servicio.
  def tipo_envio_icono(tipo)
    ICONOS.fetch(tipo.codigo.to_s.downcase) do
      tipo.modalidad == "maritimo" ? :barco : "paper-airplane"
    end
  end

  # El punto único por el que pasan los tres lugares que pintan un tipo de
  # envío. Existe para que el `:barco` no obligue a cada vista a preguntar si
  # el ícono es un heroicon o un partial.
  # `opciones` se le reenvían a la gema (`manifiestos/_form` necesita
  # `disable_default_class`). El barco no las usa: no trae clase por default,
  # justamente para que `css` sea lo único que lo viste.
  def icono_de_tipo_envio(tipo, variant: :outline, css: "w-6 h-6", **opciones)
    icono = tipo_envio_icono(tipo)

    if icono == :barco
      render("shared/icono_barco", variant: variant, css: css)
    else
      heroicon(icono, variant: variant, options: { class: css }.merge(opciones))
    end
  end
end
