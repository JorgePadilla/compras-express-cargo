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
  has_many :pre_factura_items, dependent: :destroy, inverse_of: :pre_factura
  has_many :paquetes, -> { distinct }, through: :pre_factura_items

  accepts_nested_attributes_for :pre_factura_items, allow_destroy: true

  ESTADOS = %w[creado pendiente facturado anulado].freeze

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true, inclusion: { in: ESTADOS }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }
  before_save :calculate_totals

  scope :activas,    -> { where.not(estado: "anulado") }
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
      paquetes.reload.each { |p| p.update!(estado: "pre_facturado") }
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
          concepto: item.concepto,
          peso_cobrar: item.peso_cobrar,
          precio_libra: item.precio_libra,
          subtotal: item.subtotal
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

    transaction do
      paquetes.reload.each do |p|
        p.update!(pre_factura_id: nil, estado: "disponible_entrega")
      end
      update!(estado: "anulado")
    end
    true
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

    paquetes = cliente.paquetes.where(id: paquete_ids).includes(:tipo_envio)
    prepagados_miami = []

    paquetes.each do |paquete|
      if paquete.prepagado_miami?
        # PR-6b: paquete pre-pagado en Miami — línea simbólica editable
        # en vez de flete completo. La marcamos como `manual` para que
        # el cajero pueda ajustar el monto antes de facturar.
        prepagados_miami << paquete
        # PR-10.a: `peso_cobrar` y `precio_libra` van en nil a propósito. Si
        # se mandan, `PreFacturaItem#calculate_subtotal_from_peso` corre en
        # before_validation y sobrescribe el monto simbólico con `peso × 0 = 0`
        # — el cobro de $1.00 se perdía en silencio desde PR-6b.
        pre_factura.pre_factura_items.build(
          paquete: paquete,
          concepto: "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia} (PREPAGADO EN MIAMI)",
          peso_cobrar: paquete.peso_cobrar,
          precio_libra: BigDecimal("0"),
          subtotal: PREPAGADO_MIAMI_SIMBOLICO,
          minimo_aplicado: true,
          origen: "manual"
        )
        next
      end

      peso   = paquete.peso_cobrar || BigDecimal("0")
      tarifa = Tarifa.resolver(
        tipo_envio: paquete.tipo_envio,
        peso: peso,
        cliente: cliente,
        # `proveedor` es a la vez columna string y nombre de asociación — se
        # busca por id para no depender de cuál gana el reader.
        proveedor: (Proveedor.find_by(id: paquete.proveedor_id) if paquete.proveedor_id),
        sucursal: paquete.sucursal
      )

      if tarifa
        cobro          = tarifa.cobro_para(peso)
        precio         = tarifa.precio_libra
        subtotal       = cobro[:subtotal]
        peso_fac       = cobro[:peso_facturado]
        aplico_minimo  = cobro[:aplico_minimo]
        concepto = "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}"
        concepto += " (mínimo de servicio)" if aplico_minimo
      else
        # Sin tarifa cargada caemos al comportamiento previo, para que un
        # servicio recién creado no facture en cero sin aviso.
        precio        = cliente.categoria_precio&.precio_para(paquete.tipo_envio) ||
                        paquete.tipo_envio&.precio_libra ||
                        BigDecimal("0")
        peso_fac      = peso
        subtotal      = (BigDecimal(peso.to_s) * BigDecimal(precio.to_s)).round(2, BigDecimal::ROUND_HALF_UP)
        aplico_minimo = false
        concepto      = "Flete #{paquete.tipo_envio&.nombre || 'Paquete'} - #{paquete.guia}"
      end

      pre_factura.pre_factura_items.build(
        paquete: paquete,
        concepto: concepto,
        peso_cobrar: peso_fac,
        precio_libra: precio,
        subtotal: subtotal,
        minimo_aplicado: aplico_minimo,
        origen: "manual"
      )
    end

    # PR-6b: exponemos los paquetes prepagados para que el controller
    # pueda mostrar un flash/banner avisando al cajero. (Análogo al
    # patrón de `nota_debito_auto` para cambio de servicio.)
    pre_factura.instance_variable_set(:@prepagados_miami_detected, prepagados_miami)

    # PR-D6.b: cargos automáticos por flags del paquete.
    paquetes.each { |p| pre_factura.aplicar_cobros_automaticos_para(p) }

    pre_factura
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
          subtotal: paquete.recolecta_monto,
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
            # aplicar el 15% al totalizar. Se guarda el neto.
            subtotal: servicio.precio_venta_sin_isv,
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

  def calculate_totals
    sub = pre_factura_items.reject(&:marked_for_destruction?)
                           .sum { |i| i.subtotal.to_d }
    self.subtotal = sub
    self.impuesto = (sub * isv_rate).round(2, BigDecimal::ROUND_HALF_UP)
    self.total    = (sub + impuesto).round(2)
  end
end
