# C33-03 · El resumen de las 6 de la tarde: lo que salió hoy hacia Honduras,
# un correo por cliente.
#
#   > "Cuando los escaneamos o les hacemos el manifiesto y salen enviados…
#   >  cambian de estatus de recibido Miami o recibido lo que sea, a
#   >  enviados. Hace un resumen del cliente."
#   > "Imaginate que recibiste tres paquetes aéreos, un express y dos
#   >  marítimos y todos salieron el mismo día: se vuelve una locura." ·
#   > "Que agarre todos los tracking, un solo correo… en una sola plantilla."
#   > "Por cliente, al cliente. No creo que valga la pena hacernos copia."
#
# Yusef, 2026-10-24. La hora: *"yo puse cinco, pero la verdad que cinco es muy
# temprano, yo diría que lo ponemos a las seis"* (`config/recurring.yml`).
#
# ── Qué es «salió» ────────────────────────────────────────────────────────
#
# Tener `fecha_enviado`, que pone el cierre del manifiesto **oficial**
# (`FinalizarManifiesto`) o el que entra a uno ya cerrado. El interno no la
# pone (va a `enviado_sucursal`) y no entra: a ése se le avisa al llegar
# (`NotificarLlegadaASucursal`).
#
# No se filtra por «hoy». El sello (`envio_notificado_at`) es lo que dice qué
# falta contar: si el worker estuvo caído un día, el resumen siguiente se pone
# al día, y el paquete que entró a un manifiesto cerrado la semana pasada (con
# la `fecha_enviado` de ese manifiesto) también se cuenta. Lo viejo lo selló
# la migración que agregó la columna.
#
# ── El cliente sin correo ─────────────────────────────────────────────────
#
# Se sella igual. Si no, cada tarde se lo vuelve a buscar, y el día que le
# cargan el correo le llega el resumen de un mes. Queda contado en el
# resultado y en el log.
class ResumenDeEnviados
  # De `enviado_honduras` hasta que la carga está en Honduras sin estar
  # disponible: si el mismo día ya pasó a aduana, igual salió hoy.
  ESTADOS = %w[enviado_honduras en_aduana consolidando_honduras].freeze

  Resultado = Struct.new(:avisados, :sin_correo, keyword_init: true)

  def self.call(ahora: Time.current) = new(ahora:).call

  def initialize(ahora: Time.current)
    @ahora = ahora
  end

  def call
    resultado = Resultado.new(avisados: 0, sin_correo: 0)

    por_avisar.group_by(&:cliente).each do |cliente, paquetes|
      if cliente.email.present?
        ResumenDeEnviosMailer.del_dia(cliente, paquetes).deliver_later
        resultado.avisados += 1
      else
        resultado.sin_correo += 1
      end
      Paquete.where(id: paquetes.map(&:id)).update_all(envio_notificado_at: @ahora)
    end

    Rails.logger.info("[resumen_de_enviados] #{resultado.avisados} cliente(s) avisados, #{resultado.sin_correo} sin correo")
    resultado
  end

  def por_avisar
    Paquete.where(estado: ESTADOS, envio_notificado_at: nil)
           .where.not(fecha_enviado: nil)
           .includes(:cliente, :tipo_envio)
           .order(:cliente_id, :tipo_envio_id, :tracking)
           .to_a
  end
end
