# `A7-08` · El aviso de que la carga llegó a la sucursal.
#
# Yusef, sobre el manifiesto interno: *"con el manifiesto notifique"* — y a
# quién: **a todos los clientes de ese manifiesto, de golpe**.
#
# Un correo **por cliente**, no por paquete: quien tiene tres cajas en el mismo
# camión recibe un correo que las nombra, no tres correos seguidos.
#
# ── Lo que este canal NO cubre ────────────────────────────────────────────
#
# Yusef pidió cuatro: *"el push del celular, el WhatsApp **o** el SMS —no lo
# vamos a atacar dos veces— y el correo. El push y el correo es como
# permanente."* Hoy el sistema **solo tiene correo**: no hay gema de push,
# WhatsApp ni SMS, y `clientes.telefono_whatsapp` es nada más un campo donde se
# guarda el número. Los otros tres necesitan proveedor, credenciales y costo.
class LlegadaASucursalMailer < ApplicationMailer
  def disponible(cliente, paquetes, sucursal)
    @cliente = cliente
    @paquetes = paquetes
    @sucursal = sucursal
    return if @cliente.email.blank? || @paquetes.empty?

    # `A7-13` · El nombre de la sucursal va en el asunto, y no es cosmético. Es
    # la queja que Yusef trajo de un cliente real: *"recibí un WhatsApp que ya
    # tengo disponible el producto… han ido a recogerlo a Tegucigalpa y no está
    # ahí"*. Decir dónde es el punto del aviso.
    mail to: @cliente.email,
         subject: "#{@paquetes.size} paquete#{"s" unless @paquetes.size == 1} disponible#{"s" unless @paquetes.size == 1} en #{@sucursal.nombre}"
  end
end
