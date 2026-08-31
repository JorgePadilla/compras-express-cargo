class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :cliente_session

  # `RP-58` · Las excepciones de permiso del rol de este request, cacheadas.
  # `can_access?` se llama ~100 veces por página; sin esto sería una consulta
  # por llamada. `CurrentAttributes` se limpia solo entre requests.
  attribute :permisos

  delegate :user, to: :session, allow_nil: true
  delegate :cliente, to: :cliente_session, allow_nil: true
end
