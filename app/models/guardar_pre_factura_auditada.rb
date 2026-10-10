# PR-P.5 / PR-P.6 · C30-18 · Guardar la pre-factura auditada: F9 o F8.
#
# **F9** — guardar, imprimir y **programar** el aviso. Yusef: *"¿cuándo pasan a
# disponibles? Cuando los agregás a la prefactura y le das F9"* — y la hora la
# pone la hoja (`C30-16`): los paquetes siguen en aduana hasta esa hora, y a
# esa hora `HacerDisponibles` (PR-P.2) los pasa a disponible y le escribe al
# cliente. Si la hora ya pasó, sale ahora (Fase 14, paso 3, `RP-78`).
#
# **F8** — guardar e imprimir con **CONSOLIDANDO** atravesado, y **no avisar**
# (PR-P.6, `C30-18`): `consolidando_at` puesto, las cajas a
# `consolidando_honduras`, `notificar_at` vacío —así `HacerDisponibles` ni la
# mira—. Es la pre-factura de un cliente que todavía espera carga: cuando llega
# la tanda que faltaba, escanear un volumen suyo **reabre** esta pre-factura en
# la pantalla (`AuditoriaDeTanda`, `:consolidando`) y la tanda nueva se le
# agrega —Yusef: *"¿desea agregar más paquetes a este volumen, o nuevo
# volumen?"*; «nuevo volumen» es esto, «a este volumen» (volver a pesar) queda
# afuera, `RP-88`—. Después, F9 sobre ella la programa como cualquier otra.
#
# **El servidor vuelve a preguntar todo.** La pantalla solo manda qué tandas y
# qué cajas se escanearon; lo que decide es esto:
#
# - toda caja de cada tanda **nueva** tiene que haberse escaneado — es la
#   auditoría. Las de las tandas que la pre-factura ya tenía ya se auditaron;
# - ninguna en otra pre-factura, el grupo completo, dentro de la hoja, sin
#   mezclar prepagadas con no prepagadas en una tanda
#   (`AuditoriaDeTanda#rechazo_de_la_tanda`, lo mismo que al escanear);
# - todas del mismo cliente, servicio, sucursal de retiro y pre-alerta
#   consolidada (`PuedenIrJuntas`, C27-17), también entre la tanda vieja y la
#   nueva. Las reglas del **volumen** (prepago, tarifa, trato de cobro) no:
#   dos tandas distintas sí van juntas, cada volumen es su línea (PR-P.11a);
# - con F9, ninguna con una tarea que bloquee el avance. Se pregunta **acá**, con
#   el auditor delante: `HacerDisponibles` la frenaría igual, pero a las 7:30 y
#   sin nadie mirando, y el cliente se quedaría sin aviso.
#
# La línea es el volumen (`ArmarPreFacturaPorVolumen`, PR-P.1). A una
# pre-factura reabierta **solo se le agregan** las líneas de las tandas nuevas:
# las de antes se quedan como estaban, con su monto. Armar la unión de nuevo no
# serviría —sus cajas ya están en esta pre-factura y `ArmarPreFacturaPorVolumen`
# las rechazaría—, y además una tarifa cambiada en el medio movería un monto
# que ya se imprimió.
#
# PR-P.8 · **Con candado.** QA apretó F9 dos veces a la vez sobre la misma
# tanda (dos pestañas; en la línea es la red que reintenta): las dos pasaban la
# validación —ninguna veía todavía la pre-factura de la otra— y la segunda
# moría en `RecordNotUnique` sobre `pre_facturas.numero`, un 500 sin JSON. Que
# quedara una sola pre-factura era suerte. Ahora, adentro de la transacción y
# **antes** de armar y validar, se bloquea la pre-factura reabierta (dos F8 que
# le agregan tandas a la misma se pisaban igual) y **todas** las cajas —las de
# sus tandas viejas y las nuevas—, en orden de id para que dos guardados no se
# esperen en cruz. El segundo espera al primero y después ve lo que el primero
# dejó: las cajas tomadas (el 422 de siempre) o la tanda ya agregada.
class GuardarPreFacturaAuditada
  class NoSePuede < StandardError; end

  # Cuántas veces se reintenta si el número de pre-factura chocó con el de
  # otro guardado simultáneo (de **otra** tanda: la misma ya la frena el
  # candado). `generate_numero` es máximo + 1, y dos que lo calculan a la vez
  # sacan el mismo.
  REINTENTOS_POR_NUMERO = 2

  MODOS = %i[avisar consolidar].freeze

  def initialize(hoja:, sesiones:, escaneadas:, user:, modo: :avisar, pre_factura_id: nil)
    @hoja = hoja
    @sesiones = Array(sesiones).map(&:to_s).compact_blank.uniq
    @escaneadas = Array(escaneadas).map(&:to_i).to_set
    @user = user
    @modo = MODOS.include?(modo.to_s.to_sym) ? modo.to_s.to_sym : :avisar
    @abierta = PreFactura.find(pre_factura_id) if pre_factura_id.present?
  end

  # La consolidando que esta tanda reabre, si alguna (`nil` si es nueva).
  def self.sesiones_de(pre_factura)
    Bulto.joins(:pre_factura_items).where(pre_factura_items: { pre_factura_id: pre_factura.id })
         .distinct.pluck(:sesion)
  end

  # Armada y sin guardar: lo que la pantalla muestra como «así queda». No pide
  # que estén todas escaneadas.
  def vista_previa
    pre_factura, = armar
    pre_factura.send(:calculate_totals)
    pre_factura
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

    if @modo == :avisar && pre_factura.notificar_at <= Time.current
      HacerDisponibles.new(ahora: Time.current).avisar_una(pre_factura.id)
    end
    pre_factura.reload
  rescue ArmarPreFacturaPorVolumen::NoSePuede => e
    raise NoSePuede, e.message
  end

  private

  def guardar_con_candado
    PreFactura.transaction do
      # Releída con `FOR UPDATE`: lo que se valida es lo que el otro F8 dejó.
      # Un objeto nuevo y no `lock!`: en un reintento la de antes trae
      # cambios a medio guardar.
      @abierta = PreFactura.lock.find(@abierta.id) if @abierta
      validar_abierta!
      bloquear_cajas!
      # Validar **antes** de armar las líneas: si otro F9 se llevó las cajas
      # mientras éste esperaba el candado, el rechazo que sale es el de
      # siempre —«ya está en la pre-factura PF-…»— y no el genérico de
      # `ArmarPreFacturaPorVolumen`.
      pre_factura, cajas, = armar { |de_la_tanda, nuevas| validar!(de_la_tanda, nuevas) }

      pre_factura.assign_attributes(atributos_del_modo(cajas))
      pre_factura.save!
      mover_cajas!(cajas)
      pre_factura
    end
  end

  # Un solo `SELECT id … ORDER BY id FOR UPDATE` sobre las cajas de las
  # tandas viejas de la reabierta y de las nuevas: las mismas que `armar` va a
  # leer, ya bloqueadas.
  def bloquear_cajas!
    viejas = @abierta ? self.class.sesiones_de(@abierta) : []
    Paquete.where(medicion_sesion: (viejas + @sesiones).uniq).order(:id).lock.pluck(:id)
  end

  def armar
    raise NoSePuede, "Escaneá primero el QR de un volumen." if @sesiones.empty?

    viejas = @abierta ? self.class.sesiones_de(@abierta) : []
    nuevas = @sesiones - viejas
    # Las cajas de la reabierta **siempre**, las mande la pantalla o no: con
    # ellas se pregunta `PuedenIrJuntas` entre la tanda vieja y la nueva, las
    # tareas que bloquean, y F9 las devuelve a aduana. Si se tomaran solo de
    # `sesiones`, un pedido con la tanda nueva sola le agregaba otro servicio y
    # dejaba las viejas consolidando con el aviso ya programado.
    cajas = Paquete.where(medicion_sesion: (viejas + @sesiones).uniq)
                   .includes(:cliente, :tipo_envio, :manifiesto).order(:id).to_a
    raise NoSePuede, "Esas tandas ya no tienen cajas: se midieron de nuevo. Escaneá otra vez." if cajas.empty?

    yield cajas, nuevas if block_given?
    cliente = @abierta&.cliente || cajas.first.cliente
    return [ ArmarPreFacturaPorVolumen.call(cliente: cliente, sesiones: nuevas, user: @user), cajas, nuevas ] unless @abierta

    pre_factura = @abierta
    if nuevas.any?
      armada = ArmarPreFacturaPorVolumen.call(cliente: cliente, sesiones: nuevas, user: @user)
      armada.pre_factura_items.each do |item|
        pre_factura.pre_factura_items.build(item.attributes.except("id", "pre_factura_id", "created_at", "updated_at"))
      end
    end
    [ pre_factura, cajas, nuevas ]
  end

  def validar_abierta!
    return unless @abierta
    return if @abierta.creado? && @abierta.consolidando_at.present? && @abierta.notificado_at.nil?

    raise NoSePuede, "La pre-factura #{@abierta.numero} ya no está consolidando: no se le puede agregar."
  end

  def validar!(cajas, nuevas)
    de_las_nuevas = cajas.select { |c| nuevas.include?(c.medicion_sesion.to_s) }
    faltan = de_las_nuevas.reject { |c| @escaneadas.include?(c.id) }
    if faltan.any?
      raise NoSePuede, "Faltan #{faltan.size} caja#{"s" if faltan.size != 1} por escanear: " \
                       "#{faltan.map { |c| codigo(c) }.join(', ')}."
    end

    auditoria = AuditoriaDeTanda.new(hoja: @hoja, abierta: @abierta)
    de_las_nuevas.group_by(&:medicion_sesion).each do |sesion, de_la_tanda|
      rechazo = auditoria.rechazo_de_la_tanda(sesion, de_la_tanda, contando_cargadas: false)
      raise NoSePuede, rechazo.mensaje if rechazo
    end

    cajas.each do |caja|
      problema = PuedenIrJuntas.new([ cajas.first ], caja).problema
      raise NoSePuede, problema.mensaje if problema && problema.motivo != "repetida"
    end

    return unless @modo == :avisar

    trabadas = cajas.select(&:tareas_bloqueantes_pendientes?)
    if trabadas.any?
      raise NoSePuede, "#{trabadas.map { |c| codigo(c) }.join(', ')} tiene una tarea pendiente que bloquea: " \
                       "cerrala antes, o el aviso no sale a la hora."
    end
  end

  # PR-P.11a · El manifiesto de la pre-factura es el **oficial** de sus cajas:
  # una auditada «Sin manifiesto oficial» queda sin, y no colgada de un interno
  # (la hoja en «editar» la lista aparte).
  def atributos_del_modo(cajas)
    oficial = cajas.find { |c| c.manifiesto&.tipo_oficial? }&.manifiesto_id
    comunes = { manifiesto_id: @abierta&.manifiesto_id || oficial,
                auditado_por: @user, fecha_trabajo: @hoja.disponible_en.to_date }
    if @modo == :consolidar
      comunes.merge(consolidando_at: @abierta&.consolidando_at || Time.current, notificar_at: nil)
    else
      comunes.merge(consolidando_at: nil, notificar_at: @hoja.disponible_en.change(sec: 0))
    end
  end

  # F8: todo lo de adentro espera consolidando. F9: lo que estaba consolidando
  # vuelve a aduana, y el paso a disponible pasa por `no_advance_with_open_tareas`
  # desde ahí (Fase 14, el modelo).
  def mover_cajas!(cajas)
    de, a = @modo == :consolidar ? %w[en_aduana consolidando_honduras] : %w[consolidando_honduras en_aduana]
    Paquete.where(id: cajas.map(&:id), estado: de).find_each { |c| c.update!(estado: a) }
  end

  def codigo(caja) = caja.numero_recepcion_visible.presence || caja.tracking
end
