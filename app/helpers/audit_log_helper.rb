# PR-D1.a: helpers para renderizar la bitácora (paper_trail versions) en
# las vistas. La tabla `versions` guarda `whodunnit` como string con el ID
# del User. Acá resolvemos el User para mostrar nombre + iniciales.
module AuditLogHelper
  # Roles autorizados a ver la bitácora (paper_trail versions). Decisión
  # Yusef 2026-04-29: admin + TODOS los supervisores. Excluye SAC, cajero,
  # digitador, entrega_despacho. Centralizado acá para evitar duplicar la
  # lista en cada vista que muestre bitácora.
  AUDIT_LOG_ROLES = %w[supervisor_miami supervisor_caja supervisor_prefactura].freeze

  def can_view_audit_log?
    user = Current.user
    return false unless user
    return true if user.admin?
    AUDIT_LOG_ROLES.include?(user.rol)
  end

  # Carga eficiente de los users referenciados por una colección de versions
  # para evitar N+1. Devuelve un hash {user_id_string => User}. Una sola
  # query por toda la colección de versions, sin importar cuántas filas
  # apunten al mismo whodunnit.
  def audit_users_index(versions)
    return {} if versions.blank?
    ids = versions.map(&:whodunnit).compact_blank.uniq
    return {} if ids.empty?
    User.where(id: ids).index_by { |u| u.id.to_s }
  end

  # Devuelve el User que disparó la version, o nil si whodunnit es blank
  # o el user fue eliminado. **Nunca hace queries por su cuenta** — sólo
  # consulta el índice precargado por audit_users_index. Esto garantiza
  # que no se cuele un N+1 aunque el caller olvide preloadear (peor caso:
  # devuelve nil y se renderiza "Sistema").
  def audit_user_for(version, users_by_id = {})
    return nil if version.whodunnit.blank?
    users_by_id[version.whodunnit]
  end

  # Etiqueta legible del evento: "creó", "actualizó", "eliminó".
  def audit_event_label(event)
    case event
    when "create"  then "creó"
    when "update"  then "actualizó"
    when "destroy" then "eliminó"
    else event.to_s
    end
  end

  # Lista de cambios humanos para una version. `object_changes` viene como
  # YAML serializado por paper_trail con `{column => [old, new]}`.
  # Filtra columnas ruidosas (timestamps).
  AUDIT_NOISY_COLUMNS = %w[updated_at created_at].freeze

  def audit_changes_summary(version, max: 5)
    return "" if version.event != "update" || version.object_changes.blank?
    changes = version.changeset rescue {}
    changes = changes.except(*AUDIT_NOISY_COLUMNS)
    return "Sin cambios significativos" if changes.empty?

    lines = changes.first(max).map do |column, (old_val, new_val)|
      "#{column}: #{audit_value(old_val)} → #{audit_value(new_val)}"
    end
    extra = changes.size > max ? " (+#{changes.size - max} más)" : ""
    lines.join(" · ") + extra
  end

  def audit_value(v)
    case v
    when nil   then "—"
    when ""    then "(vacío)"
    when Date, DateTime, Time, ActiveSupport::TimeWithZone then v.strftime("%Y-%m-%d %H:%M")
    else            v.to_s.truncate(40)
    end
  end
end
