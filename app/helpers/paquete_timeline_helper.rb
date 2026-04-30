# PR-D1.b: helpers para la línea de tiempo del paquete y el indicador
# "(modificada)" cuando una fecha fue re-editada después de su set
# inicial. Aprovecha paper_trail.versions para detectar re-edits.
module PaqueteTimelineHelper
  # Pasos de la línea de tiempo en orden cronológico de pipeline.
  # Cada item: { label, fecha_attr, user_attr, icon, accent }.
  TIMELINE_STEPS = [
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

    TIMELINE_STEPS.map do |step|
      fecha = paquete.send(step[:fecha_attr])
      uid   = paquete.send(step[:user_attr])
      step.merge(
        fecha: fecha,
        user:  uid && users_index[uid.to_s],
        modificada: fecha_modificada?(paquete, step[:fecha_attr])
      )
    end
  end

  # Resuelve los users referenciados por las columnas *_by_user_id en una
  # sola query.
  def paquete_timeline_users_index(paquete)
    user_ids = TIMELINE_STEPS.map { |s| paquete.send(s[:user_attr]) }.compact.uniq
    return {} if user_ids.empty?
    User.where(id: user_ids).index_by { |u| u.id.to_s }
  end

  # Devuelve true si la fecha en cuestión tuvo más de UNA actualización en
  # paper_trail (la primera la cuenta como creación; subsiguientes como
  # "modificada"). Yusef pidió un indicador visual cuando una fecha fue
  # re-editada (típicamente fecha_recibido_miami).
  def fecha_modificada?(paquete, fecha_attr)
    return false unless paquete.send(fecha_attr).present?
    column = fecha_attr.to_s
    paquete.versions.where(event: "update").select do |v|
      v.changeset.key?(column)
    rescue
      false
    end.size >= 1
  end

  def timeline_accent(accent)
    ACCENT_CLASSES.fetch(accent, ACCENT_CLASSES["navy"])
  end
end
