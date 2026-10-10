# PR-P.2 · El aviso de que la carga ya se puede retirar (`C30-16`).
#
# Yusef, el 2026-10-09, dictándolo: *"le informamos que su pedido número tal
# ya está disponible, con valor tal, con el tipo de envío tal; por favor
# acercarse a…"* — y la sucursal donde retira, que es el punto del aviso
# (`A7-13`: *"han ido a recogerlo a Tegucigalpa y no está ahí"*). La hora va
# sin segundos (`C30-08`).
#
# Lo encola `HacerDisponibles` a la hora de la fecha de trabajo y se arma
# **cuando sale**: lo que se corrigió en la pre-factura antes de la hora sale
# corregido. Es obligatorio: no mira `notificar_facturas`, que es la
# preferencia de recibir la factura por correo, no el aviso de retiro.
#
# Solo correo. WhatsApp, SMS y push quedan para `RP-80`, igual que en
# `LlegadaASucursalMailer`.
class PreFacturaMailer < ApplicationMailer
  def disponible(pre_factura)
    @pre_factura = pre_factura
    @cliente = pre_factura.cliente
    return if @cliente.nil? || @cliente.email.blank?

    cajas = pre_factura.paquetes.includes(:sucursal, :tipo_envio).to_a
    @sucursales = cajas.filter_map(&:sucursal).uniq.presence || [ @cliente.sucursal_retiro ].compact
    @tipos_envio = cajas.filter_map { |c| c.tipo_envio&.nombre }.uniq
    @cajas = cajas.size
    @hora = (pre_factura.notificar_at || pre_factura.notificado_at || Time.current).in_time_zone
    @valor = "#{pre_factura.moneda == 'USD' ? '$' : 'L.'} " \
             "#{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', pre_factura.total.to_d))}"

    donde = @sucursales.map(&:nombre).to_sentence(two_words_connector: " y ", last_word_connector: " y ")
    mail to: @cliente.email,
         subject: "Su pedido #{pre_factura.numero} ya está disponible#{" en #{donde}" if donde.present?}"
  end
end
