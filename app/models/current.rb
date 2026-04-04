class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :cliente_session

  delegate :user, to: :session, allow_nil: true
  delegate :cliente, to: :cliente_session, allow_nil: true
end
