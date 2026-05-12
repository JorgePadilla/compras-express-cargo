# PR-D1.b: helpers para la línea de tiempo del paquete y el indicador
# "(modificada)" cuando una fecha fue re-editada después de su set
# inicial. Aprovecha paper_trail.versions para detectar re-edits.
module PaqueteTimelineHelper
  # Pasos de la línea de tiempo en orden cronológico de pipeline.
  # Cada item: { label, fecha_attr, user_attr, icon, accent, optional? }.
  # `optional: true` => no se renderiza si la fecha está en blanco
  # (no aplica a todos los paquetes — ej. recolecta es opt-in).
  TIMELINE_STEPS = [
    { label: "Solicitud Recolecta", fecha_attr: :fecha_solicito_recolecta, user_attr: :fecha_solicito_recolecta_by_user_id, icon: "phone-arrow-up-right", accent: "navy", optional: true },
    { label: "Pre-Alerta",         fecha_attr: :fecha_pre_alerta,        user_attr: :fecha_pre_alerta_by_user_id,        icon: "bell-alert",     accent: "navy"  },
    { label: "Recibido en Miami",  fecha_attr: :fecha_recibido_miami,    user_attr: :fecha_recibido_miami_by_user_id,    icon: "inbox-arrow-down", accent: "navy" },
    { label: "Empacado",           fecha_attr: :fecha_empacado,          user_attr: :fecha_empacado_by_user_id,          icon: "cube",           accent: "navy"  },
    { label: "Enviado a HND",      fecha_attr: :fecha_enviado,           user_attr: :fecha_enviado_by_user_id,           icon: "paper-airplane", accent: "gold"  },
    { label: "Aduana",             fecha_attr: :fecha_aduana,            user_attr: :fecha_aduana_by_user_id,            icon: "shield-check",   accent: "gold"  },
    { label: "Consolidando",       fecha_attr: :fecha_consolidando,      user_attr: :fecha_consolidando_by_user_id,      icon: "archive-box",    accent: "gold"  },
    { label: "Disponible",         fecha_attr: :fecha_disponible,        user_attr: :fecha_disponible_by_user_id,        icon: "check-badge",    accent: "teal"  },
    { label: "En reparto",         fecha_attr: :fecha_en_reparto,        user_attr: :fecha_en_reparto_by_user_id,        icon: "truck",          accent: "teal"  },
    { label: "Entregado",          fecha_attr: :fecha_entregado,         user_attr: :fecha_entregado_by_user_id,         icon: "hand-thumb-up",  accent: "teal"  }
  ].freeze

  ACCENT_CLASSES = {
    "navy" => { bg: "bg-cec-navy",       text: "text-cec-navy",       border: "border-cec-navy/30" },
    "gold" => { bg: "bg-cec-gold-dark",  text: "text-cec-gold-dark",  border: "border-cec-gold/30" },
    "teal" => { bg: "bg-cec-teal-dark",  text: "text-cec-teal-dark",  border: "border-cec-teal/30" }
  }.freeze

  def paquete_timeline_steps(paquete, users_index = nil)
    users_index ||= paquete_timeline_users_index(paquete)

    TIMELINE_STEPS.filter_map do |step|
      fecha = paquete.send(step[:fecha_attr])
      next if step[:optional] && fecha.blank?

      uid = paquete.send(step[:user_attr])
      step.merge(
        fecha: fecha,
        user:  uid && users_index[uid.to_s],
        modificada: fecha_modificada?(paquete, step[:fecha_attr]),
        contexto: timeline_step_contexto(paquete, step[:fecha_attr])
      )
    end
  end

  # Datos extra a mostrar por step según fecha_attr. Devuelve array de
  # tuples: [icon, text] o [icon, text, link_path]. La vista renderiza
  # los de 3 elementos como link_to y los de 2 como span.
  def timeline_step_contexto(paquete, fecha_attr)
    case fecha_attr
    when :fecha_solicito_recolecta
      tarifa = paquete.tarifa_recolecta
      if tarifa
        [ [ "receipt-percent", "#{tarifa.monto} #{tarifa.moneda} · #{tarifa.zona}" ] ]
      elsif paquete.recolecta_monto.present?
        [ [ "receipt-percent", "#{paquete.recolecta_monto} #{paquete.recolecta_moneda || 'USD'}" ] ]
      else
        []
      end
    when :fecha_pre_alerta
      pa = paquete.pre_alerta_paquetes.first&.pre_alerta
      return [] unless pa
      pieces = [ [ "bell-alert", pa.numero_documento, pre_alerta_path(pa) ] ]
      pieces << [ "document-text", pa.titulo ] if pa.titulo.present?
      pieces
    when :fecha_enviado
      m = paquete.manifiesto
      m ? [ [ "paper-airplane", m.numero, manifiesto_path(m) ] ] : []
    when :fecha_aduana
      bodega = paquete.sub_localidad_actual&.codigo
      bodega ? [ [ "building-storefront", "Bodega #{bodega}" ] ] : []
    when :fecha_consolidando
      pieces = []
      pieces << [ "building-storefront", "Bodega #{paquete.sub_localidad_actual.codigo}" ] if paquete.sub_localidad_actual
      if paquete.pre_factura
        pieces << [ "document-text", paquete.pre_factura.numero, pre_factura_path(paquete.pre_factura) ]
      end
      pieces
    when :fecha_disponible
      pieces = []
      suc = paquete.sucursal_actual || paquete.sucursal
      if suc
        label = suc.codigo_ep.present? ? "#{suc.codigo_ep} · #{suc.nombre}" : "Sucursal #{suc.nombre}"
        pieces << [ "map-pin", label ]
      end
      if paquete.fecha_posible_entrega.present?
        pieces << [ "calendar", "Programada #{paquete.fecha_posible_entrega.strftime('%d/%m/%Y')}" ]
      end
      pieces
    when :fecha_en_reparto
      entrega = paquete.entrega
      return [] unless entrega
      pieces = [ [ "truck", entrega.numero, entrega_path(entrega) ] ]
      pieces << [ "user", entrega.repartidor.nombre ] if entrega.repartidor
      pieces
    when :fecha_entregado
      entrega = paquete.entrega
      return [] unless entrega
      pieces = [ [ "truck", entrega.numero, entrega_path(entrega) ] ]
      pieces << [ "user", "Firmó #{entrega.receptor_nombre}" ] if entrega.receptor_nombre.present?
      pieces
    else
      []
    end
  end

  # Resuelve los users referenciados por las columnas *_by_user_id en una
  # sola query.
  def paquete_timeline_users_index(paquete)
    user_ids = TIMELINE_STEPS.map { |s| paquete.send(s[:user_attr]) }.compact.uniq
    return {} if user_ids.empty?
    User.where(id: user_ids).index_by { |u| u.id.to_s }
  end

  # Devuelve true si la fecha en cuestión fue REASIGNADA — la primera vez
  # que se setea (de nil a un valor) cuenta como creación, no como
  # modificación. Yusef pidió un indicador visual sólo cuando una fecha
  # ya seteada se cambia (típicamente fecha_recibido_miami re-editada o
  # fecha_pre_alerta al mover el paquete a otra PA).
  def fecha_modificada?(paquete, fecha_attr)
    return false unless paquete.send(fecha_attr).present?
    column = fecha_attr.to_s
    paquete.versions.where(event: "update").any? do |v|
      cs = v.changeset rescue nil
      cs.is_a?(Hash) && cs[column].is_a?(Array) && cs[column][0].present?
    end
  end

  def timeline_accent(accent)
    ACCENT_CLASSES.fetch(accent, ACCENT_CLASSES["navy"])
  end
end
