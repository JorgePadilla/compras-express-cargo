# PR-P.2 · Disponible programado (Fase 14, `C30-16`, PR-D1 §A, `A7-16`).
#
# La pre-factura se termina en la tarde y el cliente se entera **a la hora de
# la fecha de trabajo** —7:30 por defecto—, no en el momento en que el auditor
# aprieta F9. Hasta esa hora la carga sigue en aduana (`docs/05:1201`:
# *"mientras espera la fecha programada, el paquete queda en estado aduana"*);
# a esa hora esto la pasa a `disponible_entrega` y le escribe al cliente.
#
# Lo corre `HacerDisponiblesProgramadasJob` cada minuto. Por cada pre-factura
# que ya llegó a su hora y no avisó:
#
# 1. si alguna caja tiene una tarea que **bloquea el avance**, no sigue: es la
#    misma regla que `Paquete#no_advance_with_open_tareas`, mirada de una vez
#    para todas las cajas —también las consolidando, que por ser un desvío el
#    validador no frena—. Queda el porqué en `notificacion_error` y se vuelve
#    a intentar al minuto siguiente, hasta que alguien cierre la tarea;
# 2. la confirma, si seguía en borrador;
# 3. pasa sus cajas de aduana o consolidando a `disponible_entrega`, **esté
#    como esté la pre-factura**: si la facturaron antes de la hora, las cajas
#    siguen en aduana y también tienen que salir;
# 4. encola el correo y sella `notificado_at` y `llegada_notificada_at`.
#
# Cada una en su transacción y con su `rescue`: una que falla deja su error
# escrito y no frena a las demás (la lección de PR-C29.19). Y con el sello, el
# job dos veces es el job una vez, y editar la pre-factura después del aviso
# **no** lo vuelve a mandar: *"su factura fue editada"* ×5 era justo lo que
# Yusef no quería.
#
# El correo se arma cuando sale (`deliver_later`), no al encolarlo: lo que se
# corrigió antes de la hora sale corregido.
class HacerDisponibles
  class Bloqueada < StandardError; end

  ESTADOS_QUE_ESPERAN = %w[en_aduana consolidando_honduras].freeze

  def self.call(ahora: Time.current) = new(ahora: ahora).call

  def initialize(ahora: Time.current)
    @ahora = ahora
  end

  # Devuelve cuántas pre-facturas avisó.
  def call
    PreFactura.por_avisar(@ahora).order(:notificar_at, :id).pluck(:id).count { |id| avisar(id) }
  end

  private

  def avisar(id)
    avisada = false
    PreFactura.transaction do
      pre_factura = PreFactura.lock.find(id)
      # Otro barrido pudo haberla avisado mientras éste esperaba el lock, o
      # alguien la anuló o le corrió la hora.
      if pre_factura.notificado_at.nil? && !pre_factura.anulado? &&
         pre_factura.notificar_at.present? && pre_factura.notificar_at <= @ahora
        hacer_disponible!(pre_factura)
        avisada = true
      end
    end
    avisada
  rescue StandardError => e
    PreFactura.where(id: id).update_all(notificacion_error: "#{@ahora.strftime('%d/%m/%Y %H:%M')} · #{e.message}".truncate(1000))
    Rails.logger.warn("[HacerDisponibles] #{id}: #{e.class}: #{e.message}")
    false
  end

  def hacer_disponible!(pre_factura)
    cajas = pre_factura.paquetes.to_a
    bloqueadas = cajas.select(&:tareas_bloqueantes_pendientes?)
    if bloqueadas.any?
      raise Bloqueada, "#{bloqueadas.map(&:guia).join(', ')} tiene una tarea pendiente que bloquea el avance: " \
                       "no se pasa a disponible ni se avisa hasta cerrarla."
    end

    pre_factura.confirmar! if pre_factura.creado?
    pre_factura.paquetes.reload.where(estado: ESTADOS_QUE_ESPERAN).find_each do |caja|
      caja.update!(estado: "disponible_entrega")
    end
    Paquete.where(id: cajas.map(&:id), llegada_notificada_at: nil).update_all(llegada_notificada_at: @ahora)

    # `C30-16` · El aviso es obligatorio: no depende de `notificar_facturas`,
    # que es la preferencia de recibir **la factura** por correo. Sin correo
    # no hay a quién escribirle, y eso no puede dejar la carga en aduana:
    # sale disponible igual y queda dicho que no se avisó.
    error = nil
    if pre_factura.cliente&.email.present?
      PreFacturaMailer.disponible(pre_factura).deliver_later
    else
      error = "#{@ahora.strftime('%d/%m/%Y %H:%M')} · El cliente no tiene correo: la carga quedó disponible sin avisarle."
    end
    pre_factura.update_columns(notificado_at: @ahora, notificacion_error: error)
  end
end
