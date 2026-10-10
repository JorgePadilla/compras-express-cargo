class PreFactura < ApplicationRecord
  include CurrencyAware
  has_paper_trail  # PR-D1.a: audit log

  include IsvAware

  # PR-6b: cuando un paquete fue prepagado en Miami (entrega personal),
  # NO se cobra el flete completo en Honduras — solo un monto simbólico
  # editable para control contable. Yusef: "la factura la va a hacer por
  # un dólar más impuesto". Constante por ahora; cuando Yusef confirme
  # el valor exacto puede moverse a un EmpresaSetting.
  PREPAGADO_MIAMI_SIMBOLICO = BigDecimal("1.00")

  belongs_to :cliente
  belongs_to :creado_por, class_name: "User", optional: true
  # PR-P.2 · Quién la auditó escaneando (PR-P.5 lo escribe).
  belongs_to :auditado_por, class_name: "User", optional: true

  # C21-10. *"Lo que vamos a seleccionar, de que estamos procesando, es el
  # manifiesto… ahí es donde deberíamos amarrar el manifiesto, no la guía."*
  # Opcional: una pre-factura de recolecta no viene de ningún manifiesto.
  belongs_to :manifiesto, optional: true
  has_many :pre_factura_items, dependent: :destroy, inverse_of: :pre_factura
  # PR-13.d: los cambios que un supervisor autorizó sobre sus líneas.
  has_many :autorizaciones, as: :documento, dependent: :destroy
  has_many :paquetes, -> { distinct }, through: :pre_factura_items

  # PR-M8. `paquetes.pre_factura_id` lo leen tres lugares —`Paquete.facturables`,
  # `Paquete#cobrada_o_entregada?` y el bloqueo de borrar del controller— y lo
  # limpian dos (`anular!` y `BajarCajasConPin`). **Nadie lo escribía**: solo
  # los seeds. O sea que el mismo paquete podía entrar en dos pre-facturas
  # borrador a la vez, y que la lista de manifiestos con carga por facturar
  # siguiera mostrando uno ya facturado entero.
  #
  # Se estampa al guardar, no al confirmar: un borrador ya reserva el paquete.
  # Se salta cuando el documento está anulado, porque `anular!` acaba de
  # ponerlo en nil y este callback corre después de su `update!`.
  after_save :vincular_paquetes

  accepts_nested_attributes_for :pre_factura_items, allow_destroy: true

  ESTADOS = %w[creado pendiente facturado anulado].freeze

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals
  # PR-P.7 · Las dos puertas a la fecha, en sync. Va **antes** de
  # `ajustar_notificar_at`: si la fecha mueve la hora, ése la redondea.
  before_save :mover_notificar_at_con_la_fecha,
              if: -> { will_save_change_to_fecha_trabajo? && !will_save_change_to_notificar_at? && notificar_at.present? }
  before_save :ajustar_notificar_at, if: :notificar_at_changed?
  validate :fecha_de_un_aviso_ya_mandado, if: -> { notificado_at.present? && will_save_change_to_fecha_trabajo? }

  # PR-P.2 · La hora a la que la carga queda disponible y se le avisa al
  # cliente, si nadie dice otra. Yusef (`C30-16`): *"siete y media"*. Se cambia
  # sin deploy con `Configuracion.set("prefactura_hora_disponible", "08:00")`,
  # como `ventana_aviso_llegada_min`.
  HORA_DISPONIBLE_DEFAULT = "07:30".freeze

  def self.hora_disponible
    valor = Configuracion.get("prefactura_hora_disponible").to_s.strip
    valor.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/) ? valor : HORA_DISPONIBLE_DEFAULT
  end

  # La fecha de trabajo con la hora de disponible, en la zona de la empresa.
  def self.notificar_at_para(fecha, hora: hora_disponible)
    h, m = hora.split(":").map(&:to_i)
    Time.zone.local(fecha.year, fecha.month, fecha.day, h, m)
  end

  scope :activas,    -> { where.not(estado: "anulado") }
  # PR-P.2 · Las que ya llegaron a su hora y todavía no avisaron. Va por el
  # índice parcial `index_pre_facturas_por_avisar`.
  scope :por_avisar, ->(ahora = Time.current) {
    activas.where(notificado_at: nil).where.not(notificar_at: nil).where(notificar_at: ..ahora)
  }
  scope :pendientes, -> { where(estado: "pendiente") }
  scope :recientes,  -> { order(created_at: :desc) }
  scope :by_cliente, ->(id) { where(cliente_id: id) }
  scope :by_estado,  ->(estado) { where(estado: estado) }
  scope :buscar, ->(term) {
    left_joins(:cliente).where(
      "pre_facturas.numero ILIKE :q OR clientes.codigo ILIKE :q OR clientes.nombre ILIKE :q",
      q: "%#{sanitize_sql_like(term)}%"
    )
  }

  ESTADOS.each do |estado|
    define_method("#{estado}?") { self.estado == estado }
  end

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  def confirmar!
    return false unless creado?

    transaction do
      update!(estado: "pendiente", confirmado_at: Time.current)
      # A7-01 · *"Bodega Honduras va **después** de prefactura"*: emitir la
      # pre-factura es lo que mete la carga a la bodega de Honduras. Antes esto
      # escribía `pre_facturado`, el estado que Yusef mandó eliminar (A7-11);
      # el paso que describe ya tenía nombre, y es éste.
      paquetes.reload.each { |p| p.update!(estado: "disponible_entrega") }
    end
    true
  end

  attr_reader :nota_debito_auto

  # PR-6b: lista de paquetes con prepagado_miami que se detectaron al
  # construir la pre-factura. El controller los usa para mostrar un
  # flash al cajero ("X paquetes prepagados — agregué cobro simbólico").
  def prepagados_miami_detected
    @prepagados_miami_detected || []
  end

  def facturar!
    return false if facturado? || anulado?

    venta = nil
    @nota_debito_auto = nil
    transaction do
      update!(estado: "pendiente", confirmado_at: confirmado_at || Time.current) if creado?

      venta = Venta.new(
        cliente: cliente,
        pre_factura: self,
        creado_por: creado_por,
        moneda: moneda,
        estado: "pendiente",
        notas: notas
      )
      pre_factura_items.each do |item|
        venta.venta_items.build(
          paquete: item.paquete,
          # PR-P.1 · Para que la factura agrupe las cajas bajo su volumen. Es
          # copiar una columna: ningún monto cambia.
          bulto: item.bulto,
          concepto: item.concepto,
          peso_cobrar: item.peso_cobrar,
          precio_libra: item.precio_libra,
          subtotal: item.subtotal,
          # PR-13.a: sin esto `VentaItem` recalcula peso × precio y pisa el
          # mínimo de servicio y el simbólico de prepagado en Miami. La
          # pre-factura decía una cosa y la factura cobraba otra.
          minimo_aplicado: item.minimo_aplicado,
          # PR-13.b: si el descuento no viaja, se le cobra al cliente lo que la
          # pre-factura ya le había descontado.
          descuento_monto: item.descuento_monto,
          descuento_porcentaje: item.descuento_porcentaje,
          descuento_motivo: item.descuento_motivo
        )
      end
      venta.save!

      paquetes_asociados = paquetes.reload.to_a
      paquetes_asociados.each { |p| p.update!(venta_id: venta.id) }

      update!(estado: "facturado", facturado_at: Time.current)
      cliente.increment!(:saldo_pendiente, venta.total)

      # Auto-crea Nota de Debito en estado 'creado' si hay paquetes con solicito_cambio_servicio.
      # El cajero debe revisarla y emitirla manualmente.
      paquetes_cambio = paquetes_asociados.select(&:solicito_cambio_servicio?)
      if paquetes_cambio.any?
        nd = NotaDebito.build_from_paquetes(
          venta,
          paquete_ids: paquetes_cambio.map(&:id),
          motivo: "cambio_servicio",
          user: creado_por
        )
        nd.notas = "Generada automaticamente al facturar PF #{numero} por paquetes con solicitud de cambio de servicio."
        nd.save!
        @nota_debito_auto = nd
      end
    end

    # Fuera de la transaction: encola email idempotente
    if venta && venta.email_pendiente_enviado_at.nil? &&
       cliente.email.present? && cliente.notificar_facturas?
      FacturaMailer.pendiente(venta).deliver_later
      venta.update_column(:email_pendiente_enviado_at, Time.current)
    end

    venta
  end

  def anular!
    return false if facturado? || anulado?

    hecho = false
    transaction do
      # PR-P.8 · La pre-factura se bloquea **antes** que sus cajas, en el mismo
      # orden que `GuardarPreFacturaAuditada`, `HacerDisponibles` y
      # `volver_a_consolidar!`. Al revés —cajas primero, como estaba—, anular
      # en el mismo segundo en que alguien apreta F8 sobre la misma
      # consolidando era un deadlock que Postgres resuelve abortando a uno
      # con un 500. Y después del candado se vuelve a mirar: el otro pudo
      # haberla facturado mientras esperábamos.
      lock!
      next if facturado? || anulado?

      # Solo se suelta la FK. El estado se queda en `disponible_entrega`, que
      # es donde `confirmar!` lo dejó y donde el paquete físicamente está:
      # anular la pre-factura no devuelve la carga a la aduana. Con la FK en
      # nil vuelve a caer en `Paquete.facturables`, que filtra por eso.
      #
      # PR-P.2 · Salvo lo que F8 había dejado consolidando (PR-P.6): eso vuelve
      # a aduana, que es donde espera la carga sin pre-factura. Quedarse en
      # `consolidando_honduras` la sacaría de `facturables` para siempre.
      paquetes.reload.each do |p|
        p.update!(pre_factura_id: nil, **(p.estado == "consolidando_honduras" ? { estado: "en_aduana" } : {}))
      end
      update!(estado: "anulado")
      hecho = true
    end
    hecho
  end

  # Builds a PreFactura + items for the given paquete_ids (scoped to the
  # cliente). Paquetes must be in bodega Honduras and not already linked to
  # a pre_factura. Precio per pound is calculated from the cliente's
  # categoria_precio (if any) or the tipo_envio default.
  def self.build_from_paquetes(cliente, paquete_ids, user: nil)
    pre_factura = new(
      cliente: cliente,
      creado_por: user,
      fecha_trabajo: Date.current
    )

    pre_factura.agregar_lineas_por_paquete(
      cliente.paquetes.facturables.where(id: paquete_ids).includes(:tipo_envio, :sucursal, :proveedor)
    )
    pre_factura
  end

  # PR-P.10 · Las líneas **por paquete** —flete con el peso de Miami, el
  # simbólico del prepagado y los cargos automáticos—, sobre una pre-factura
  # que ya existe sin guardar. Es el cuerpo de `build_from_paquetes`.
  #
  # PR-P.11b · Ninguna pantalla lo llama ya (la puerta a mano se fue): lo usan
  # los seeds y los tests que necesitan una pre-factura con precio. Se borra en
  # P.11c, cuando esos pasen a medir y armar por volumen.
  #
  # `paquetes` llega ya filtrado a los facturables del cliente. Los prepagados
  # se **acumulan** en `prepagados_miami_detected`: la pre-factura puede venir
  # del armador por volumen, que nunca los anota.
  def agregar_lineas_por_paquete(paquetes)
    paquetes.each do |paquete|
      if paquete.prepagado_miami?
        # PR-6b: paquete pre-pagado en Miami — línea simbólica editable
        # en vez de flete completo. PR-P.11a: el cuerpo vive en
        # `linea_prepagado_miami`, que comparte con el armador por volumen;
        # acá lleva el peso del paquete, como siempre.
        pre_factura_items.build(
          linea_prepagado_miami(paquete, peso_cobrar: paquete.peso_cobrar, precio_libra: BigDecimal("0"))
        )
        next
      end

      peso   = paquete.peso_cobrar || BigDecimal("0")
      tarifa = Tarifa.resolver(
        tipo_envio: paquete.tipo_envio,
        peso: peso,
        cliente: cliente,
        proveedor: paquete.proveedor,
        sucursal: paquete.sucursal
      )

      if tarifa
        cobro          = tarifa.cobro_para(peso)
        peso_fac       = cobro[:peso_facturado]
        aplico_minimo  = cobro[:aplico_minimo]
        # PR-10.a: las tarifas están en USD y el documento en Lempiras. Se
        # convierte el precio unitario y el subtotal se recalcula sobre él,
        # para que la factura cuadre a la vista del cliente (peso × precio =
        # subtotal). El mínimo es un total, así que ese se convierte directo.
        precio   = convertir_a_moneda(tarifa.precio_libra, tarifa.moneda)
        subtotal = if aplico_minimo
          convertir_a_moneda(cobro[:subtotal], cobro[:moneda])
        else
          (peso_fac * precio).round(2, BigDecimal::ROUND_HALF_UP)
        end
        concepto = "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}"
        concepto += " (mínimo de servicio)" if aplico_minimo
      else
        # A7-25. Acá había un fallback: si `Tarifa.resolver` no encontraba nada,
        # se cobraba con `categoria_precio.precio_para` y, si tampoco, con
        # `tipo_envio.precio_libra`. O sea, con la tabla vieja — sin mínimo, sin
        # escalonado, y colapsando los cinco servicios a "aéreo o marítimo".
        #
        # Es justo la duplicación que Yusef encontró: *"no me había fijado que
        # tenías otra tabla del otro lado"*. Un fallback que cobra distinto que
        # la tarifa es peor que no tener fallback — el propio
        # `TarifasPropuesta2026` ya lo dice cuando sincroniza
        # `tipo_envios.precio_libra`.
        #
        # Ahora la tabla vieja **no se consulta**. La línea se arma en cero y lo
        # dice en el concepto, para que el cajero no la pueda pasar por alto y
        # alguien cargue la tarifa en /servicios.
        #
        # Se eligió esto y no cortar con un error porque el cajero tiene al
        # cliente enfrente: un precio en cero que grita es peor negocio que
        # facturar, pero mejor que cobrar en silencio con la tabla equivocada.
        precio        = BigDecimal("0")
        peso_fac      = peso
        subtotal      = BigDecimal("0")
        aplico_minimo = false
        concepto      = "⚠ SIN TARIFA CARGADA — #{paquete.tipo_envio&.nombre || 'servicio'} - #{paquete.guia}"
      end

      pre_factura_items.build(
        paquete: paquete,
        concepto: concepto,
        peso_cobrar: peso_fac,
        precio_libra: precio,
        subtotal: subtotal,
        minimo_aplicado: aplico_minimo,
        origen: "manual"
      )
    end

    # PR-D6.b: cargos automáticos por flags del paquete.
    paquetes.each { |p| aplicar_cobros_automaticos_para(p) }

    self
  end

  # PR-6b · PR-P.11a · La línea simbólica de un paquete **prepagado en Miami**
  # —los atributos, para `pre_factura_items.build`—: no se cobra el flete,
  # solo el simbólico, editable por el cajero (`origen: "manual"`). Yusef:
  # *"la factura la va a hacer por un dólar más impuesto"*; el simbólico está
  # en USD y el documento en Lempiras, y el ISV lo suma el total como a
  # cualquier línea.
  #
  # Sacado tal cual de `agregar_lineas_por_paquete` para que el armador por
  # volumen (`ArmarPreFacturaPorVolumen`) cobre **lo mismo** por caja. La
  # diferencia es el peso: por paquete la línea lleva el de la caja (es su
  # flete); por volumen va **sin peso ni precio** —el peso ya lo lleva la
  # línea del volumen, y con él `EtiquetaDeEntrega#libras` lo contaría dos
  # veces y `LineasPorVolumen` la escondería como una caja más—.
  #
  # `minimo_aplicado: true` es lo que la protege (PR-10.a): sin él,
  # `PreFacturaItem#calculate_subtotal_from_peso` pisaba el monto con
  # `peso × 0 = 0` y el dólar se perdía en silencio.
  #
  # Anota el paquete en `prepagados_miami_detected` (PR-6b), venga de donde
  # venga la línea.
  def linea_prepagado_miami(paquete, peso_cobrar: nil, precio_libra: nil)
    (@prepagados_miami_detected ||= []) << paquete

    { paquete: paquete,
      concepto: "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia} " \
                "(PREPAGADO EN MIAMI#{paquete.prepago_sufijo})",
      peso_cobrar: peso_cobrar,
      precio_libra: precio_libra,
      subtotal: convertir_a_moneda(PREPAGADO_MIAMI_SIMBOLICO, "USD"),
      minimo_aplicado: true,
      origen: "manual" }
  end

  # PR-P.10 · Los totales de un documento **sin guardar**, con la misma cuenta
  # que el `before_save` (descuento → ISV half-up). Lo usaba el preview de la
  # pre-factura a mano (PR-P.11b la quitó); quedan los tests, hasta P.11c.
  def calcular_totales
    calculate_totals
    self
  end

  # PR-10.a: convierte un monto a la moneda de ESTA pre-factura, usando la
  # tasa congelada si ya existe (documento viejo) o la vigente si es nueva.
  #
  # Es el arreglo del bug mas caro que tenia el sistema: los precios de
  # `tarifas` / `tipo_envios` estan en dolares, la pre-factura nace en
  # Lempiras, y nadie convertia — `CurrencyAware#convertir` existia y no se
  # llamaba desde ningun lado. Un CER de 10 lb salia "L. 45.00" cuando son
  # $45, o sea unas 25 veces menos de lo que corresponde cobrar.
  def convertir_a_moneda(monto, desde)
    return BigDecimal("0") if monto.blank?

    CurrencyAware.convertir(
      monto,
      de: desde.to_s.presence || moneda,
      a: moneda,
      tasa: tasa_cambio_aplicada || CurrencyAware.tasa_vigente
    )
  end

  # PR-D6.b: agrega líneas auto al pre_factura por cada flag activo en
  # el paquete (recolecta_solicitada, solicito_cambio_servicio).
  # Idempotente: si ya hay líneas auto para ese paquete, no las duplica
  # (el caller debe limpiar antes con `pre_factura_items.auto.destroy_all`
  # si quiere re-generar desde cero).
  def aplicar_cobros_automaticos_para(paquete)
    if paquete.recolecta_solicitada? && paquete.recolecta_monto.to_d.positive?
      ya_existe = pre_factura_items.any? { |i|
        i.origen == "auto_recolecta" && i.paquete_id == paquete.id && !i.marked_for_destruction?
      }
      unless ya_existe
        pre_factura_items.build(
          paquete: paquete,
          concepto: "Recolecta - #{paquete.guia}",
          # La tarifa de recolecta se carga en USD por default.
          subtotal: convertir_a_moneda(paquete.recolecta_monto, paquete.recolecta_moneda),
          minimo_aplicado: true, # es un monto fijo, no sale de peso × precio
          origen: "auto_recolecta"
        )
      end
    end

    if paquete.solicito_cambio_servicio?
      servicio = ServicioExtra.activos.find_by(codigo: "CAMBIO_SERVICIO")
      if servicio
        ya_existe = pre_factura_items.any? { |i|
          i.origen == "auto_servicio_extra" &&
            i.paquete_id == paquete.id &&
            i.servicio_extra_id == servicio.id &&
            !i.marked_for_destruction?
        }
        unless ya_existe
          pre_factura_items.build(
            paquete: paquete,
            servicio_extra: servicio,
            concepto: "#{servicio.descripcion} - #{paquete.guia}",
            # PR-10.a: `precio_incluye_isv` existía en la tabla y se ignoraba,
            # así que a un servicio con el ISV ya adentro se le volvía a
            # aplicar el 15% al totalizar. Se guarda el neto, convertido a la
            # moneda del documento (el catálogo se carga en USD).
            #
            # PR-C6.12: y con el piso aplicado. `cobro_para` devuelve el neto
            # ya en la moneda del documento, así que no hay round-trip: el
            # mínimo de un cargo en USD con piso en Lempiras se compara en
            # Lempiras una sola vez.
            subtotal: servicio.cobro_para(1, en: moneda),
            minimo_aplicado: true, # monto fijo del catálogo
            origen: "auto_servicio_extra"
          )
        end
      end
    end
  end

  private

  def generate_numero
    next_number = (self.class.where("numero LIKE 'PF-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
    self.numero = "PF-#{next_number.to_s.rjust(6, '0')}"
  end

  # PR-P.2 · `C30-08`: la hora va **sin segundos** —en el papel y en el
  # correo—, así que se guarda sin ellos. Y `fecha_trabajo` sigue siendo su
  # día: los filtros y los listados la leen a ella.
  def ajustar_notificar_at
    return if notificar_at.nil?

    self.notificar_at = notificar_at.in_time_zone.change(sec: 0)
    self.fecha_trabajo = notificar_at.to_date
  end

  # PR-P.7 · QA: el formulario de la pre-factura sigue permitiendo
  # `fecha_trabajo` suelto, y con P.2 eso dejaba la fecha diciendo un día y el
  # aviso saliendo otro. Se decidió **mover** el aviso y no bloquear: cambiar el
  # día de trabajo de una programada es justamente decir «avisá ese día», y la
  # hora es la que ya tenía (la de la hoja, o la que se reprogramó). Bloquear
  # obligaría a ir a otra pantalla para algo que la fecha ya dice.
  def mover_notificar_at_con_la_fecha
    self.notificar_at = Time.zone.local(fecha_trabajo.year, fecha_trabajo.month, fecha_trabajo.day,
                                        notificar_at.hour, notificar_at.min)
  end

  # …salvo que el aviso ya haya salido (`RP-77`): ahí la fecha es historia.
  # Cambiarla diría que se avisó otro día, y el cliente ya recibió el correo.
  def fecha_de_un_aviso_ya_mandado
    errors.add(:fecha_trabajo, "no se cambia: el aviso ya se mandó el #{notificado_at.strftime('%d/%m/%Y %H:%M')}")
  end

  public

  # ── PR-P.7 · Corregir antes del aviso ─────────────────────────────────

  class YaAvisada < StandardError; end

  # En qué anda el aviso, para la hoja en modo «editar».
  def estado_del_aviso
    return :avisada if notificado_at.present?
    return :consolidando if consolidando_at.present?
    return :error if notificacion_error.present?
    return :programada if notificar_at.present?

    :sin_aviso
  end

  # PR-P.9 · Confirmar y Facturar, a mano, sobre una que salió de la auditoría.
  #
  # «Confirmar» (`confirmar!`) pasa las cajas a `disponible_entrega` en el acto.
  # Sobre una **programada** eso se saltea la hora que eligió la hoja y la guarda
  # de tareas que `HacerDisponibles#hacer_disponible!` pregunta antes; sobre una
  # **consolidando**, suelta cajas que todavía esperan a las otras. `:error` es
  # una programada cuyo aviso no salió —casi siempre una tarea que bloquea— y
  # que el job vuelve a intentar cada minuto: confirmarla a mano es saltearse
  # justo eso.
  #
  # «Facturar» sobre una programada no rompe nada: no toca las cajas, y a la
  # hora el job igual las pasa y avisa. Sobre una **consolidando** sí: no tiene
  # hora, así que nadie las pasaría nunca a disponible.
  #
  # La regla vive acá y no en `confirmar!`, porque `HacerDisponibles` llama a
  # `confirmar!` justamente a la hora. Devuelve el porqué, o nil.
  def motivo_para_no_confirmar
    return nil unless creado?

    case estado_del_aviso
    when :programada, :error
      "Se avisa sola el #{notificar_at.strftime('%d/%m a las %H:%M')}: ahí pasa a disponible. " \
        "Para adelantarla, cambiá la hora en Preparar pre-factura › Editar."
    when :consolidando
      "Está consolidando: se cierra con F9 desde Auditar, que le pone la hora del aviso."
    end
  end

  def motivo_para_no_facturar
    return nil unless creado? && estado_del_aviso == :consolidando

    "Está consolidando: se cierra con F9 desde Auditar antes de facturarla."
  end

  # `RP-78` / `C30-18` · *"¿Y si se equivocan con F9? — Pueden reversarlo y
  # poner F8."* Solo mientras el aviso no salió (`RP-77`: retirar uno ya mandado
  # no se puede, el correo ya está en la bandeja del cliente). Es lo mismo que
  # deja F8: `consolidando_at`, sin hora, y las cajas esperando consolidando.
  def volver_a_consolidar!
    raise YaAvisada, "#{numero} ya se le avisó al cliente: no vuelve a consolidando." if notificado_at.present?
    raise YaAvisada, "#{numero} ya no está abierta (#{estado})." unless creado?

    transaction do
      update!(consolidando_at: Time.current, notificar_at: nil, notificacion_error: nil)
      paquetes.reload.where(estado: "en_aduana").find_each { |p| p.update!(estado: "consolidando_honduras") }
    end
  end

  private

  def vincular_paquetes
    return if anulado?

    ids = paquetes.reload.ids

    # Soltar lo que ya no está en el documento. Cubre el caso en que la línea
    # se quita por `accepts_nested_attributes_for … allow_destroy` y la
    # pre-factura se vuelve a guardar en el mismo request.
    sobrantes = Paquete.where(pre_factura_id: id)
    sobrantes = sobrantes.where.not(id: ids) if ids.any?
    sobrantes.update_all(pre_factura_id: nil)

    return if ids.empty?

    # `IS DISTINCT FROM` y no `where.not`: con la columna en NULL —que es el
    # caso de todo paquete que entra por primera vez— `pre_factura_id != :id`
    # evalúa a NULL, no a TRUE, y el UPDATE no tocaba ni una fila. Con el
    # guardia puesto bien, la segunda y siguientes guardadas de la misma
    # pre-factura no escriben nada.
    #
    # Va por `update_all` a propósito: `update!` correría las validaciones del
    # paquete, y en esta bodega hay paquetes guardados incompletos — una
    # validación que falle acá reventaría el guardado de la pre-factura entera.
    # Es el mismo criterio que ya usan `BajarCajasConPin` y los seeds.
    Paquete.where(id: ids)
           .where("pre_factura_id IS DISTINCT FROM ?", id)
           .update_all(pre_factura_id: id)
  end

  # PR-13.b: el descuento reduce la base del ISV, que es el orden contable
  # normal — el impuesto se calcula sobre lo que realmente se le cobra al
  # cliente, no sobre el bruto. Con `descuento` en 0 el resultado es idéntico
  # al de antes, así que ninguna pre-factura existente se mueve.
  #
  # PR-F2.1 · La cuenta la hace la gema (`Fiscal::Totales`), la misma que va a
  # imprimir la factura SAR. Da idéntico a la fórmula de antes, centavo por
  # centavo: `test/services/fiscal/totales_equivalencia_test.rb`.
  def calculate_totals
    vivos = pre_factura_items.reject(&:marked_for_destruction?)
    t = Fiscal::Totales.calcular(vivos, moneda: moneda)

    self.subtotal  = t[:subtotal]
    self.descuento = t[:descuento]
    self.impuesto  = t[:impuesto]
    self.total     = t[:total]
  end
end
