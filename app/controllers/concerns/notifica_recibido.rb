# El correo de «paquete recibido en Miami», y cuándo se manda.
#
# Hasta C18-06 el único disparador vivía adentro de `link_pre_alertas` en
# /etiquetar: se mandaba solo si el tracking tenía pre-alerta. Los paquetes
# «enviados según política» no tienen pre-alerta por definición, así que la
# nota que se les compone al cliente no le habría llegado nunca.
#
# Decisión de Jorge (2026-08-26): se manda cuando hay pre-alerta **o** nota de
# política — no a todo recibido. Un solo sitio de envío, para que un paquete
# pre-alertado **y** con política mande un correo y no dos. Lo usan
# /etiquetar, /entrega_personal y el form de /paquetes (la corrección tardía
# también notifica).
module NotificaRecibido
  extend ActiveSupport::Concern

  private

  def notificar_recibido(paquete, pre_alerta_vinculada:)
    return unless pre_alerta_vinculada || paquete.enviado_por_politica?
    return if paquete.cliente&.email.blank?

    PreAlertaMailer.paquete_recibido(paquete.cliente, paquete).deliver_later
  end
end
