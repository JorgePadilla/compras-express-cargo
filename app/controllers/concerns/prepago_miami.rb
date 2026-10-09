# El marcado de "pagado aquí en Miami", compartido por las dos pantallas que lo
# ofrecen: `/entrega_personal` y `/etiquetar`.
#
# ── Por qué es un concern y no un método en cada controller ───────────────
#
# El flag es uno solo pero se traduce a **cinco** columnas —sucursal, usuario,
# fecha y método, más el booleano—. Escrito dos veces, dentro de un mes una
# pantalla sella el método y la otra no, y el cajero de Honduras ve
# "PREPAGADO EN MIAMI" sin forma de pago en la mitad de los paquetes.
#
# Es exactamente la forma de bug que este repo viene repitiendo: dos pantallas
# de Miami que hacen lo mismo y se van separando sin que nadie lo decida.
module PrepagoMiami
  extend ActiveSupport::Concern

  # Los params que las dos pantallas tienen que permitir.
  PARAMS = %i[prepagado_miami prepagado_miami_metodo].freeze

  private

  # Sella —o limpia— el rastro del prepago sobre un paquete todavía sin
  # guardar. No guarda: eso lo decide quien llama.
  def aplicar_prepago_miami(paquete, origen = params)
    return unless origen.dig(:paquete)&.key?("prepagado_miami")

    if ActiveModel::Type::Boolean.new.cast(origen.dig(:paquete, :prepagado_miami))
      paquete.prepagado_miami          = true
      paquete.prepagado_miami_metodo   = origen.dig(:paquete, :prepagado_miami_metodo).presence
      paquete.prepagado_miami_sucursal = paquete.sucursal
      paquete.prepagado_miami_by_user  = Current.user
      paquete.prepagado_miami_at       = Time.current
    else
      # La rama que faltaba. El código viejo solo actuaba cuando el flag venía
      # en true, así que desmarcar el prepago dejaba el rastro puesto: fecha,
      # usuario y sucursal de un cobro que ya no existe.
      limpiar_prepago_miami(paquete)
    end
  end

  def limpiar_prepago_miami(paquete)
    paquete.prepagado_miami          = false
    paquete.prepagado_miami_metodo   = nil
    paquete.prepagado_miami_sucursal = nil
    paquete.prepagado_miami_by_user  = nil
    paquete.prepagado_miami_at       = nil
  end
end
