# C33-03 · Lo que salió hoy, en un solo correo por cliente, agrupado por tipo
# de envío y con la fecha probable de entrega. Lo arma `ResumenDeEnviados`.
#
# El texto es provisional: Yusef va a mandar su plantilla (*"te puedo dar una
# plantilla a mi gusto"*, C33-01).
class ResumenDeEnviosMailer < ApplicationMailer
  def del_dia(cliente, paquetes)
    @cliente = cliente
    @paquetes = paquetes
    return if @cliente.email.blank? || @paquetes.empty?

    @por_tipo = paquetes.group_by { |p| p.tipo_envio&.nombre || "Sin tipo de envío" }
    mail to: @cliente.email,
         subject: (paquetes.size == 1 ? "Su paquete salió hoy hacia Honduras" : "Sus #{paquetes.size} paquetes salieron hoy hacia Honduras")
  end
end
