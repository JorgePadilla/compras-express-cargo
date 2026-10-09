class DashboardHeroComponent < ViewComponent::Base
  # `signos:` · PR-C29.16. El semáforo barato del servidor (`SignosVitales.nivel_rapido`)
  # cuando quien mira puede entrar a «Signos del servidor»; `nil` si no, y
  # entonces el ícono no sale.
  def initialize(user:, health_status:, time: Time.zone.now, signos: nil)
    @user = user
    @health_status = health_status || { level: :ok, message: "Operación saludable" }
    @time = time
    @signos = signos
  end

  def signos? = !@signos.nil?

  # El puntito del ícono, en los colores del semáforo de la página.
  def color_signos = { bien: "bg-cec-teal", mirar: "bg-cec-gold", problema: "bg-red-600" }.fetch(@signos, "bg-gray-400")

  def texto_signos = SignosVitales::TITULO.fetch(@signos, "sin medir")

  def display_name
    @user.respond_to?(:nombre) && @user.nombre.present? ? @user.nombre.split.first : @user.email_address
  end

  def long_date
    formatted = I18n.l(@time.to_date, format: "%A %-d de %B")
    formatted.sub(/^./, &:upcase)
  end
end
