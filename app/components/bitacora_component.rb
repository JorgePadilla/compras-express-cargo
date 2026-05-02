# Bitácora visual estilo timeline. Reemplaza el partial
# shared/_bitacora.html.erb (que ahora delega a este componente).
#
# Yusef 2026-05-02: la bitácora era difícil de entender porque mostraba
# nombres de columna crudos, IDs en lugar de nombres, y todos los
# cambios en una línea sin jerarquía. Este componente:
#
#   - Renderiza cada versión como un nodo en un timeline vertical.
#   - Resuelve FKs (cliente_id → "Juan Pérez (CEC-001)") sin N+1.
#   - Traduce columnas a labels humanos (notas_consolidacion → "Notas
#     de consolidación").
#   - Destaca cambios de estado en uppercase con jerarquía mayor.
#   - Muestra fecha relativa ("Hace 4 horas") + absoluta.
class BitacoraComponent < ViewComponent::Base
  def initialize(record:, label: nil, limit: 50)
    @record = record
    @label = label.presence || record.class.name
    @limit = limit
  end

  def visible?
    helpers.can_view_audit_log? && @record.respond_to?(:versions)
  end

  def versions
    @versions ||= @record.versions.reorder(created_at: :desc).limit(@limit)
  end

  def users_index
    @users_index ||= helpers.audit_users_index(versions)
  end

  def fk_index
    @fk_index ||= helpers.audit_fk_index(versions)
  end

  def total_count
    @total_count ||= @record.versions.count
  end

  def truncated?
    total_count > @limit
  end
end
