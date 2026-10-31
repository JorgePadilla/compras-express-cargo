# PR-P.5 · C30-17 · Lo que lee la pistola en «Auditar pre-factura», y por qué.
#
# Yusef, 2026-10-09 (audio a3_1427):
#
#   > "Escanear cualquiera de estas: automáticamente escanean una, **jala los
#   >  tres volúmenes**… tres de tres, y ahora te dice **escanear los paquetes
#   >  que van con esto**." — "Y te va diciendo: son siete paquetes."
#   > "Solo con uno escanea los otros dos. No ocupamos escanear los tres."
#   > "Ahora escanean los paquetes, le va a decir… Sí, **pertenece**."
#
# Dos clases de escaneo, y se distinguen por el **prefijo** `MED`, no buscando
# el código: el QR del volumen lleva el código de la primera caja de la tanda
# (`etiqueta_qr_medicion`), y la etiqueta de Miami de esa caja resuelve a la
# misma caja. Buscando, un volumen y una caja serían indistinguibles.
#
# Esto **solo clasifica**; el que escribe es `GuardarPreFacturaAuditada`, que
# vuelve a preguntar todo. La pantalla lleva la cuenta de qué tandas y qué
# cajas se escanearon y la manda en cada pedido: no hay estado en el servidor
# entre un escaneo y el siguiente.
class AuditoriaDeTanda
  Resultado = Struct.new(:tipo, :mensaje, :sesion, :cajas, :bultos, :caja, :pre_factura, :aviso, :grupo_aviso,
                         keyword_init: true) do
    def ok? = tipo.in?(%i[ok pertenece])
  end

  def self.volumen?(codigo) = Paquete::QR_DE_MEDICION.match?(codigo.to_s.strip)

  # El «n de m» que la etiqueta del volumen lleva al final del QR
  # (`etiqueta_qr_medicion`: `MED <código> <peso> <medidas> 2de3`). Una
  # medición sola no lleva nada: es 1 de 1.
  NDEM = /(?<n>\d+)de(?<m>\d+)\s*\z/i

  def self.total_impreso(codigo)
    m = NDEM.match(codigo.to_s.strip)
    m ? m[:m].to_i : 1
  end

  # `hoja`: la hoja de preparación del que audita (sus servicios y manifiestos).
  # `sesiones`: las tandas que ya están en la pantalla.
  # `abierta`: la pre-factura consolidando que la pantalla reabrió (PR-P.6), si
  # alguna: sus cajas no cuentan como «ya en otra pre-factura».
  def initialize(hoja:, sesiones: [], abierta: nil)
    @hoja = hoja
    @sesiones = Array(sesiones).map(&:to_s).compact_blank.uniq
    @abierta = abierta
  end

  # ── Un volumen (el QR `MED …`) ───────────────────────────────────────────
  def volumen(codigo)
    return Resultado.new(tipo: :no_es_volumen, mensaje: "Eso no es el QR de un volumen: escaneá la etiqueta de medición.") unless self.class.volumen?(codigo)

    caja = Paquete.por_codigo_de_etiqueta(codigo).first
    return no_encontrado(codigo) if caja.nil?

    sesion = caja.medicion_sesion
    bultos = sesion.present? ? Bulto.de_la_sesion(sesion).to_a : []
    if caja.medido_at.blank? || bultos.empty?
      return Resultado.new(tipo: :sin_medir,
                           mensaje: "#{codigo_de(caja)} todavía no está medido: medilo primero en Medición.")
    end

    cajas = Paquete.where(medicion_sesion: sesion).includes(:cliente, :tipo_envio, :manifiesto).order(:id).to_a
    rechazo = rechazo_de_la_tanda(sesion, cajas)
    return rechazo if rechazo

    avisos = [ medicion_anterior(codigo, bultos), prepagadas_aviso(cajas) ].compact
    Resultado.new(tipo: :ok, sesion: sesion, cajas: cajas, bultos: bultos, aviso: avisos.join(" · ").presence,
                  grupo_aviso: grupo_aviso(cajas, sesion),
                  mensaje: "#{volumenes_texto(bultos)} · #{cajas.size} paquete#{"s" if cajas.size != 1}: escaneá cada etiqueta de Miami.")
  end

  # Después de medir de nuevo (`C30-11`), la etiqueta **vieja** de un volumen
  # sigue resolviendo a la tanda de hoy —el QR lleva el código de la primera
  # caja, y la caja es la misma—. Si el «de m» impreso no es lo que la tanda
  # tiene hoy, el papel está viejo: se avisa, y la tanda de hoy se carga igual
  # (es la que se cobra).
  def medicion_anterior(codigo, bultos)
    impreso = self.class.total_impreso(codigo)
    hoy = bultos.first&.de_cuantos.to_i
    hoy = bultos.size if hoy.zero?
    return nil if impreso == hoy

    "Esta etiqueta es de una medición anterior: la tanda hoy tiene #{volumenes_texto_n(hoy)} — reimprimí las etiquetas."
  end

  # PR-P.11a · RP-89 · Una tanda prepagada en Miami entra (el armador pone el
  # simbólico), pero el auditor tiene que saber que no se le cobra el flete:
  # es lo que antes decía el modal de la puerta a mano.
  def prepagadas_aviso(cajas)
    n = cajas.count(&:prepagado_miami?)
    return nil if n.zero?

    simbolico = format("%.2f", PreFactura::PREPAGADO_MIAMI_SIMBOLICO)
    "#{n} paquete#{"s" if n != 1} prepagado#{"s" if n != 1} en Miami: se cobra el simbólico de US$#{simbolico} c/u, no el flete."
  end

  # C34-07 · El grupo al que le falta carga ya no frena: se dice qué falta y
  # dónde está, y el auditor elige. F8 guarda consolidando —*"cliente inicia el
  # consolidado"*— y F9 pregunta antes de avisar. Una clave aparte de `aviso`:
  # aquella suena como «etiqueta vieja», y esto no es un error.
  def grupo_aviso(cajas, sesion)
    pendientes = self.class.grupos_pendientes(cajas)
    return nil if pendientes.empty?

    en_pantalla = @sesiones + [ sesion.to_s ]
    pendientes.map { |g| "#{g.nombre} no está completo: #{g.lo_que_falta(en_pantalla: en_pantalla)}." }
              .join(" ") + " F8 lo guarda consolidando; F9 pregunta antes de avisar."
  end

  # Los grupos de estas cajas a los que les falta algo, uno por grupo.
  def self.grupos_pendientes(cajas)
    cajas.filter_map(&:grupo_pendiente).uniq(&:clave)
  end

  # ── Una caja (la etiqueta de Miami) ─────────────────────────────────────
  #
  # `escaneadas`: los ids que la pantalla ya marcó.
  def caja(codigo, escaneadas: [])
    caja = Paquete.por_codigo_de_etiqueta(codigo).includes(:cliente).first
    return no_encontrado(codigo) if caja.nil?

    if @sesiones.empty?
      return Resultado.new(tipo: :sin_volumen, caja: caja,
                           mensaje: "Primero el volumen: escaneá el QR de la etiqueta de medición.")
    end

    unless @sesiones.include?(caja.medicion_sesion.to_s)
      return Resultado.new(tipo: :no_corresponde, caja: caja, mensaje: no_corresponde_msg(caja))
    end

    if Array(escaneadas).map(&:to_i).include?(caja.id)
      return Resultado.new(tipo: :ya_escaneada, caja: caja, mensaje: "#{codigo_de(caja)} ya lo escaneaste.")
    end

    Resultado.new(tipo: :pertenece, caja: caja, mensaje: "#{codigo_de(caja)} pertenece.")
  end

  # Lo que impide pre-facturar una tanda. Lo usa también `GuardarPreFacturaAuditada`,
  # que lo vuelve a preguntar al guardar: entre el escaneo y el F9 alguien pudo
  # haber hecho otra pre-factura con estas cajas. Ojo: el último chequeo
  # (`no_va_junto`) compara contra las tandas **ya cargadas**; al guardar no hay
  # «ya cargadas» y no dice nada — ahí `GuardarPreFacturaAuditada` corre
  # `PuedenIrJuntas` sobre todas las cajas juntas.
  def rechazo_de_la_tanda(sesion, cajas, contando_cargadas: true)
    if contando_cargadas && @sesiones.include?(sesion.to_s)
      return Resultado.new(tipo: :repetido, mensaje: "Esa tanda ya está en pantalla: escaneá sus cajas.")
    end

    if (con_pf = cajas.find { |c| c.pre_factura_id && c.pre_factura_id != @abierta&.id })
      pf = PreFactura.find_by(id: con_pf.pre_factura_id)
      return consolidando(pf, con_pf) if consolidando_reabrible?(pf, con_pf)

      return Resultado.new(tipo: :ya_prefacturada, pre_factura: pf,
                           mensaje: "#{codigo_de(con_pf)} ya está en la pre-factura #{pf&.numero}.")
    end

    # C34-07 · Lo que traba es **no estar medido**. El grupo incompleto dejó
    # de trabar acá (`grupo_aviso`): antes, la primera tanda de un consolidado
    # no llegaba nunca a crear la pre-factura que F8 después reabre.
    if (sin_medir = cajas.find { |c| c.medido_at.blank? })
      return Resultado.new(tipo: :sin_medir,
                           mensaje: "#{codigo_de(sin_medir)} todavía no está medido: medilo primero en Medición.")
    end

    # El servicio tiene que ser uno de los de la hoja.
    #
    # C31-14 · **El manifiesto ya no frena** (cierra `RP-85`). Yusef,
    # 2026-10-12: *"aquí todo debe dejarte meter de otros manifiestos. Lo que no
    # debe dejarte meter… es que sean de diferentes tipos de envío. Y el nombre,
    # lógico"* · *"le quitamos la restricción de otro manifiesto… porque puede
    # estar cruzado… está muy estricto"*. Hasta acá había un quinto paso
    # (`HojaDePreparacion#acepta_manifiesto?`) que rechazaba la caja de un
    # manifiesto que no estaba en la hoja, o sin manifiesto oficial si la hoja
    # no marcó «Sin manifiesto oficial». Quedan el servicio (acá) y cliente y
    # servicio entre tandas (`PuedenIrJuntas`, en `no_va_junto`). Lo corre
    # también `GuardarPreFacturaAuditada#validar!` al guardar: es esta misma
    # regla, no una copia.
    if (afuera = cajas.find { |c| !@hoja.tipo_envio_ids.include?(c.tipo_envio_id) })
      return Resultado.new(tipo: :fuera_de_la_hoja,
                           mensaje: "#{codigo_de(afuera)} va por #{afuera.tipo_envio&.nombre}, y la hoja es de " \
                                    "#{nombres_de_tipos}. Cambiá la hoja si toca trabajar ese servicio.")
    end

    # PR-P.11a · RP-89 · Toda prepagada entra con el simbólico (el aviso lo da
    # `volumen`); mezclada no: el volumen pesó las dos cosas juntas. Medición
    # ya no deja medirlas así (`PuedenIrJuntas#prepago_mezclado`); esto es
    # para las tandas medidas antes.
    prepagadas = cajas.select(&:prepagado_miami?)
    if prepagadas.any? && prepagadas.size < cajas.size
      return Resultado.new(tipo: :prepagada,
                           mensaje: "#{codigo_de(prepagadas.first)} viene prepagada en Miami y el resto de la " \
                                    "tanda no: medila de nuevo separando las prepagadas.")
    end

    no_va_junto(cajas.first)
  end

  private

  # PR-P.6 · Una tanda que está en una pre-factura que F8 dejó **consolidando**
  # —sin avisar, esperando la carga que falta— no es «ya pre-facturada»: es la
  # puerta para agregarle la tanda nueva. Yusef: *"tenemos que escanear primero
  # el volumen… ¿desea agregar más paquetes a este volumen, o nuevo volumen?"*.
  def consolidando_reabrible?(pf, caja)
    pf.present? && pf.creado? && pf.consolidando_at.present? && pf.notificado_at.nil? &&
      pf.cliente_id == caja.cliente_id
  end

  def consolidando(pf, caja)
    if @sesiones.any? || @abierta
      return Resultado.new(tipo: :ya_prefacturada, pre_factura: pf,
                           mensaje: "#{codigo_de(caja)} está en la pre-factura #{pf.numero}, consolidando. " \
                                    "Para agregarle carga, limpiá la pantalla (F2) y escaneá primero este volumen.")
    end

    Resultado.new(tipo: :consolidando, pre_factura: pf,
                  mensaje: "La pre-factura #{pf.numero} está consolidando: escaneá el volumen nuevo que se le agrega.")
  end

  # C27-17 · Una pre-factura es de un cliente, un servicio y una pre-alerta
  # consolidada: la misma regla que la mesa de medición (`PuedenIrJuntas`).
  def no_va_junto(primera)
    return nil if @sesiones.empty?

    # Todas las cargadas, no la primera: la sucursal de retiro se compara con
    # las que la tienen (QA de PR-P.11a, `PuedenIrJuntas#sucursal_que_choca`).
    ya = Paquete.where(medicion_sesion: @sesiones).includes(:cliente, :tipo_envio, :sucursal).order(:id).to_a
    problema = PuedenIrJuntas.new(ya, primera).problema
    return nil if problema.nil?

    Resultado.new(tipo: :no_va_junto, mensaje: problema.mensaje)
  end

  def no_encontrado(codigo)
    Resultado.new(tipo: :no_encontrado, mensaje: "No existe ningún paquete con «#{Paquete.limpiar_codigo_escaneado(codigo)}».")
  end

  def no_corresponde_msg(caja)
    ya = Paquete.where(medicion_sesion: @sesiones).includes(:cliente).first
    if ya && ya.cliente_id != caja.cliente_id
      "#{codigo_de(caja)} es de #{caja.cliente&.nombre_completo}, no de #{ya.cliente&.nombre_completo}: no corresponde."
    else
      "#{codigo_de(caja)} no es de esta tanda: no corresponde."
    end
  end

  def volumenes_texto(bultos) = volumenes_texto_n(bultos.size)

  def volumenes_texto_n(n) = n == 1 ? "1 volumen" : "#{n} volúmenes"

  def nombres_de_tipos
    TipoEnvio.where(id: @hoja.tipo_envio_ids).order(:nombre).pluck(:nombre).to_sentence
  end

  def codigo_de(caja)
    recepcion = caja.numero_recepcion_visible
    return caja.tracking if recepcion.blank?
    return recepcion unless caja.dividido? && caja.numero_caja.to_i.positive?

    "#{recepcion}-#{caja.numero_caja}"
  end
end
