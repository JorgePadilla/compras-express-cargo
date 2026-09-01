class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :cliente_session

  # `RP-58` · Las excepciones de permiso del rol de este request, cacheadas.
  # `can_access?` se llama ~100 veces por página; sin esto sería una consulta
  # por llamada. `CurrentAttributes` se limpia solo entre requests.
  attribute :permisos

  # `RP-58` paso 2b · Los títulos renombrados, por la misma razón: `rol_label` se
  # llama por fila en los listados, y una consulta por llamada sería absurda.
  attribute :titulos

  delegate :user, to: :session, allow_nil: true
  delegate :cliente, to: :cliente_session, allow_nil: true
end
