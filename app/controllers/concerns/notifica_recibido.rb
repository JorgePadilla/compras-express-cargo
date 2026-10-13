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

  #
  # C31-11 · Antes del correo se fija la «posible fecha de entrega», que es lo
  # que el correo ahora dice en lugar de *"será incluido en el próximo envío
  # disponible"*. Va **arriba** de las guardas a propósito: el cliente la ve en
  # su portal aunque el paquete no tenga pre-alerta y no le llegue correo. Y se
  # guarda antes de encolar, porque el job del correo vuelve a leer el paquete.
  #
  # `cajas` son las N de un split: un correo por envío, pero la fecha la lleva
  # cada caja.
  def notificar_recibido(paquete, pre_alerta_vinculada:, cajas: [ paquete ])
    cajas.each(&:fijar_fecha_posible_entrega)

    return unless pre_alerta_vinculada || paquete.enviado_por_politica?
    return if paquete.cliente&.email.blank?

    PreAlertaMailer.paquete_recibido(paquete.cliente, paquete).deliver_later
  end
end
