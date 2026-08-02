class DashboardHeroComponent < ViewComponent::Base
  def initialize(user:, health_status:, time: Time.zone.now)
    @user = user
    @health_status = health_status || { level: :ok, message: "Operación saludable" }
    @time = time
  end

  def display_name
    @user.respond_to?(:nombre) && @user.nombre.present? ? @user.nombre.split.first : @user.email_address
  end

  def long_date
    formatted = I18n.l(@time.to_date, format: "%A %-d de %B")
    formatted.sub(/^./, &:upcase)
  end
end
