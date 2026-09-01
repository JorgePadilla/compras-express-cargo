# `A7-08` · Avisarle a todos los clientes del manifiesto interno que su carga
# llegó.
#
#   > **Jorge:** "¿Solo con que escanee el manifiesto le notifique a todos los
#   >  clientes en Tegucigalpa, o que escanee paquete por paquete?"
#   > **Yusef:** "Con el manifiesto notifique, pero **darle una ventana de media
#   >  hora, por ejemplo, o una hora**."
#
# ── Por qué NO hay ventana de espera ──────────────────────────────────────
#
# La ventana es un trabajo diferido, y **la cola de trabajos de este repo no
# está conectada**: `solid_queue` está en el `Gemfile` y `render.yaml` levanta
# dos workers que corren `rails solid_queue:start`, pero del lado de Rails nunca
# se cableó — el adaptador efectivo en producción es `AsyncAdapter`, no existe
# `db/queue_migrate` ni `config/queue.yml`, y no hay una sola tabla de
# `solid_queue` en la base. El propio comentario que quedó sin descomentar en
# `config/environments/production.rb` lo dice: *"non-durable queuing backend"*.
#
# Un job agendado a 30-60 minutos sobre `:async` se pierde en el primer reinicio,
# y en Render hay deploys y spin-down: el cliente **no recibiría el aviso, sin
# error y sin rastro**.
#
# Jorge, 2026-09-01, con esa información sobre la mesa: **notificar al cerrar la
# recepción, sin ventana**. Se pierde el motivo que Yusef le daba —*"escanean el
# manifiesto y empiezan a escanear paquete por paquete para cuadrar"*—, pero al
# cerrar ese conteo **ya terminó**, que es justo lo que la ventana venía a
# esperar. `RP-32` (¿media hora o una hora?) queda sin efecto hasta que la cola
# se conecte.
#
# ── Quién recibe ──────────────────────────────────────────────────────────
#
# Solo los paquetes que **de verdad llegaron**: los que quedaron
# `disponible_entrega` al escanearlos. El que no se escaneó sigue en
# `enviado_sucursal` y no se avisa — avisarlo sería mandar al cliente a buscar
# algo que no está, que es la queja que `A7-13` documenta.
class NotificarLlegadaASucursal
  def initialize(manifiesto)
    @manifiesto = manifiesto
  end

  # Un correo por cliente, no por paquete: quien tiene tres cajas en el mismo
  # camión recibe un correo que las nombra, no tres correos seguidos.
  #
  # Devuelve a cuántos clientes se les avisó.
  def call
    return 0 unless @manifiesto.tipo_interno? && @manifiesto.sucursal_entrega

    avisados = 0

    paquetes_llegados.group_by(&:cliente).each do |cliente, paquetes|
      next if cliente.nil? || cliente.email.blank?

      LlegadaASucursalMailer.disponible(cliente, paquetes, @manifiesto.sucursal_entrega)
                            .deliver_later
      avisados += 1
    end

    avisados
  end

  def paquetes_llegados
    @manifiesto.paquetes.where(estado: "disponible_entrega").includes(:cliente).to_a
  end
end
