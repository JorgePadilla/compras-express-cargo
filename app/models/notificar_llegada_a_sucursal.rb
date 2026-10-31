# `A7-08` · Avisarle a todos los clientes del manifiesto interno que su carga
# llegó.
#
#   > **Jorge:** "¿Solo con que escanee el manifiesto le notifique a todos los
#   >  clientes en Tegucigalpa, o que escanee paquete por paquete?"
#   > **Yusef:** "Con el manifiesto notifique, pero **darle una ventana de media
#   >  hora, por ejemplo, o una hora**."
#
# ── La ventana ────────────────────────────────────────────────────────────
#
# Del 2026-09-01 al 2026-09-06 esto avisaba **al cerrar la recepción, sin
# ventana**, porque la cola de trabajos no estaba conectada y un job diferido
# sobre `:async` se pierde en el primer deploy. Jorge, 2026-09-06: *"se hablaba
# de un delay que se va a usar colas; te había dicho que no, que lo hiciéramos
# instantáneo, pero con que más cosas ocupas colas, definitivamente hagámoslo"*.
#
# Ahora hay **dos que avisan**, y por eso la idempotencia vive en el paquete
# (`llegada_notificada_at`) y no en el cierre:
#
# 1. La **ventana**: con el primer paquete escaneado se programa
#    `NotificarLlegadaASucursalJob` a `ventana_minutos` — `RP-32` (¿media hora
#    o una hora?) sigue abierta; va en 30 y se cambia sin deploy con
#    `Configuracion.set("ventana_aviso_llegada_min", "60")`. Cuando dispara,
#    avisa lo escaneado hasta ahí.
# 2. **Cerrar la recepción**: avisa a los que faltaban. Si la ventana ya pasó,
#    son los escaneados después; si no, son todos, y el job después no
#    encuentra a nadie.
#
# Se programa **una** vez por manifiesto (`aviso_llegada_programado_at`): el
# segundo paquete escaneado no arma un segundo job.
#
# ── Quién recibe ──────────────────────────────────────────────────────────
#
# Solo los paquetes que **de verdad llegaron** y no fueron avisados: los que
# quedaron `disponible_entrega` al escanearlos. El que no se escaneó sigue en
# `enviado_sucursal` y no se avisa — avisarlo sería mandar al cliente a buscar
# algo que no está, que es la queja que `A7-13` documenta.
class NotificarLlegadaASucursal
  VENTANA_DEFAULT_MIN = 30

  def self.ventana_minutos
    Configuracion.get("ventana_aviso_llegada_min").to_i.then { |m| m.positive? ? m : VENTANA_DEFAULT_MIN }
  end

  # A7-08 · Se llama al escanear cada paquete del interno; programa el aviso
  # la primera vez y no hace nada las demás.
  def self.programar(manifiesto)
    return false unless manifiesto.tipo_interno?
    return false if manifiesto.aviso_llegada_programado_at.present?

    manifiesto.update_column(:aviso_llegada_programado_at, Time.current)
    NotificarLlegadaASucursalJob.set(wait: ventana_minutos.minutes).perform_later(manifiesto)
    true
  end

  # C34-08 · La hora la pone **quien recibe**: *"llegan 200 paquetes a Alexis,
  # no va a estar el sistema notificándole en el acto los 200… ¿a qué hora es
  # lo notificado? Tal hora"*. Si la puso (`aviso_llegada_at`), ni la ventana
  # ni el cierre avisan antes: avisa este barrido, que corre cada minuto en
  # `HacerDisponiblesProgramadasJob`. Si la corre, el aviso se corre con ella.
  # Sin hora puesta, todo sigue como antes: la ventana y el cierre.
  def self.barrer(ahora = Time.current)
    Manifiesto.where(tipo: "interno", aviso_llegada_at: (ahora - 3.days)..ahora).find_each.sum do |m|
      new(m).call
    end
  end

  # ¿Ya es hora? Sin hora puesta, sí (los manifiestos de antes).
  def self.hora_de_avisar?(manifiesto, ahora = Time.current)
    manifiesto.aviso_llegada_at.nil? || manifiesto.aviso_llegada_at <= ahora
  end

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
    llegados = paquetes_llegados

    # C34-08 · La pre-factura que F9 dejó esperando la sucursal: el aviso es
    # **el de siempre** —la pre-factura disponible, con su monto—, cuando
    # llegaron todas sus cajas. La que llegó a medias espera al resto.
    pre_facturas_que_esperan(llegados).each do |pf|
      cajas = pf.paquetes.to_a
      next unless cajas.all? { |c| c.estado == "disponible_entrega" && llego?(c) }

      if pf.cliente&.email.present?
        PreFacturaMailer.disponible(pf).deliver_later
        pf.update_columns(notificado_at: Time.current)
      else
        pf.update_columns(notificado_at: Time.current,
                          notificacion_error: "#{Time.current.strftime('%d/%m/%Y %H:%M')} · El cliente no tiene correo: llegó a la sucursal sin avisarle.")
      end
      Paquete.where(id: cajas.map(&:id)).update_all(llegada_notificada_at: Time.current)
      avisados += 1
    end
    de_pre_facturas = PreFactura.where(id: llegados.filter_map(&:pre_factura_id)).where.not(espera_llegada_at: nil).pluck(:id).to_set
    llegados = llegados.reject { |p| de_pre_facturas.include?(p.pre_factura_id) }

    llegados.group_by(&:cliente).each do |cliente, paquetes|
      next if cliente.nil? || cliente.email.blank?

      LlegadaASucursalMailer.disponible(cliente, paquetes, @manifiesto.sucursal_entrega)
                            .deliver_later
      # El sello va después de encolar, en la misma transacción del request:
      # si el correo no se encola, el paquete queda sin sellar y el siguiente
      # que avise lo agarra.
      Paquete.where(id: paquetes.map(&:id)).update_all(llegada_notificada_at: Time.current)
      avisados += 1
    end

    avisados
  end

  # Los que llegaron y todavía no fueron avisados — por ningún camino.
  def paquetes_llegados
    @manifiesto.paquetes.where(estado: "disponible_entrega", llegada_notificada_at: nil).includes(:cliente).to_a
  end

  private

  def pre_facturas_que_esperan(paquetes)
    PreFactura.where(id: paquetes.filter_map(&:pre_factura_id).uniq, notificado_at: nil)
              .where.not(espera_llegada_at: nil).includes(:cliente, :paquetes).to_a
  end

  # Está donde retira: lo que el interno escribió al recibirla.
  def llego?(caja)
    retira = caja.sucursal || caja.cliente&.sucursal_retiro || Sucursal.para_cliente_nuevo
    caja.sucursal_actual_id.present? && caja.sucursal_actual_id == retira&.id
  end
end
