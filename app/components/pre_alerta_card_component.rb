class PreAlertaCardComponent < ViewComponent::Base
  def initialize(pre_alerta:)
    @pre_alerta = pre_alerta
  end

  private

  attr_reader :pre_alerta
end
