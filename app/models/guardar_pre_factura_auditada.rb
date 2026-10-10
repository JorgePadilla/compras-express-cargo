# PR-P.5 · C30-18 · F9: la pre-factura auditada se guarda, se imprime su
# etiqueta de entrega, y el aviso al cliente queda **programado** a la hora de
# la fecha de trabajo.
#
# Yusef: *"¿cuándo pasan a disponibles? Cuando los agregás a la prefactura y le
# das F9"* — y la hora la pone la hoja (`C30-16`): los paquetes siguen en
# aduana hasta esa hora, y a esa hora `HacerDisponibles` (PR-P.2) los pasa a
# disponible y le escribe al cliente. Si la hora ya pasó, sale ahora (Fase 14,
# paso 3, `RP-78`).
#
# **El servidor vuelve a preguntar todo.** La pantalla solo manda qué tandas y
# qué cajas se escanearon; lo que decide es esto:
#
# - toda caja de cada tanda tiene que haberse escaneado — es la auditoría;
# - ninguna en otra pre-factura, el grupo completo, dentro de la hoja, sin
#   prepago (`AuditoriaDeTanda#rechazo_de_la_tanda`, lo mismo que al escanear:
#   entre el escaneo y el F9 alguien pudo haber hecho otra pre-factura);
# - todas del mismo cliente, servicio y pre-alerta consolidada (`PuedenIrJuntas`,
#   C27-17);
# - ninguna con una tarea que bloquee el avance. Se pregunta **acá**, con el
#   auditor delante: `HacerDisponibles` la frenaría igual, pero a las 7:30 y sin
#   nadie mirando, y el cliente se quedaría sin aviso.
#
# La línea es el volumen (`ArmarPreFacturaPorVolumen`, PR-P.1).
#
# PR-P.8 · **Con candado.** QA apretó F9 dos veces a la vez sobre la misma
# tanda (dos pestañas; en la línea es la red que reintenta): las dos pasaban la
# validación —ninguna veía todavía la pre-factura de la otra— y la segunda
# moría en `RecordNotUnique` sobre `pre_facturas.numero`, un 500 sin JSON. Que
# quedara una sola pre-factura era suerte: con un instante más de diferencia
# salían dos, cobrando las mismas cajas. Ahora las cajas se bloquean
# (`FOR UPDATE`, en orden de id para que dos guardados no se esperen en
# cruz) **adentro** de la transacción y **antes** de validar: el segundo F9
# espera al primero y después ve las cajas tomadas, que es el 422 de siempre.
class GuardarPreFacturaAuditada
  class NoSePuede < StandardError; end

  # Cuántas veces se reintenta si el número de pre-factura chocó con el de
  # otro guardado simultáneo (de **otra** tanda: la misma ya la frena el
  # candado). `generate_numero` es máximo + 1, y dos que lo calculan a la vez
  # sacan el mismo.
  REINTENTOS_POR_NUMERO = 2

  def initialize(hoja:, sesiones:, escaneadas:, user:)
    @hoja = hoja
    @sesiones = Array(sesiones).map(&:to_s).compact_blank.uniq
    @escaneadas = Array(escaneadas).map(&:to_i).to_set
    @user = user
  end

  def call
    raise NoSePuede, "Escaneá primero el QR de un volumen." if @sesiones.empty?

    intentos = 0
    begin
      pre_factura = guardar_con_candado
    rescue ActiveRecord::RecordNotUnique => e
      # La transacción entera se deshizo: volver a empezar es seguro, y el
      # candado decide de nuevo si las cajas siguen libres.
      intentos += 1
      retry if intentos <= REINTENTOS_POR_NUMERO && e.message.include?("numero")
      raise NoSePuede, "Otra pre-factura se guardó al mismo tiempo y no se pudo numerar esta. Apretá F9 de nuevo."
    end

    HacerDisponibles.new(ahora: Time.current).avisar_una(pre_factura.id) if pre_factura.notificar_at <= Time.current
    pre_factura.reload
  rescue ArmarPreFacturaPorVolumen::NoSePuede => e
    raise NoSePuede, e.message
  end

  private

  def guardar_con_candado
    pre_factura = nil
    PreFactura.transaction do
      # El candado primero, y recién después leer y validar: lo que se valida
      # es lo que ya está bloqueado. `pluck` con `lock` hace un solo
      # `SELECT id … ORDER BY id FOR UPDATE`.
      ids = Paquete.where(medicion_sesion: @sesiones).order(:id).lock.pluck(:id)
      cajas = Paquete.where(id: ids).includes(:cliente, :tipo_envio, :manifiesto).order(:id).to_a
      validar!(cajas)

      pre_factura = ArmarPreFacturaPorVolumen.call(cliente: cajas.first.cliente, sesiones: @sesiones, user: @user)
      pre_factura.assign_attributes(
        manifiesto_id: cajas.first.manifiesto_id,
        auditado_por: @user,
        notificar_at: @hoja.disponible_en.change(sec: 0),
        fecha_trabajo: @hoja.disponible_en.to_date,
        consolidando_at: nil
      )
      pre_factura.save!
      # Lo que estaba consolidando vuelve a aduana: el paso a disponible pasa
      # por `no_advance_with_open_tareas` desde ahí (Fase 14, el modelo).
      Paquete.where(id: cajas.map(&:id), estado: "consolidando_honduras").find_each { |c| c.update!(estado: "en_aduana") }
    end
    pre_factura
  end

  def validar!(cajas)
    raise NoSePuede, "Esas tandas ya no tienen cajas: se midieron de nuevo. Escaneá otra vez." if cajas.empty?

    faltan = cajas.reject { |c| @escaneadas.include?(c.id) }
    if faltan.any?
      raise NoSePuede, "Faltan #{faltan.size} caja#{"s" if faltan.size != 1} por escanear: " \
                       "#{faltan.map { |c| codigo(c) }.join(', ')}."
    end

    auditoria = AuditoriaDeTanda.new(hoja: @hoja)
    cajas.group_by(&:medicion_sesion).each do |sesion, de_la_tanda|
      rechazo = auditoria.rechazo_de_la_tanda(sesion, de_la_tanda, contando_cargadas: false)
      raise NoSePuede, rechazo.mensaje if rechazo
    end

    cajas.each do |caja|
      problema = PuedenIrJuntas.new([ cajas.first ], caja).problema
      raise NoSePuede, problema.mensaje if problema && problema.motivo != "repetida"
    end

    trabadas = cajas.select(&:tareas_bloqueantes_pendientes?)
    if trabadas.any?
      raise NoSePuede, "#{trabadas.map { |c| codigo(c) }.join(', ')} tiene una tarea pendiente que bloquea: " \
                       "cerrala antes, o el aviso no sale a la hora."
    end
  end

  def codigo(caja) = caja.numero_recepcion_visible.presence || caja.tracking
end
