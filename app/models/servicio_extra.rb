# PR-D6.a: catálogo de servicios/productos extra que se cargan en
# la pre-factura. Yusef 2026-05-01:
#   "ya incluye ISV — debe haber un area donde crea los servicios /
#    productos y pone Costos, Precio en venta, Tipo de cobro (USD/LPS)"
#
# Ejemplos típicos: cambio de servicio, peso adicional, manejo
# especial. Los cargos se agregan automáticamente a la pre-factura
# cuando el paquete tiene los flags correspondientes (recolecta o
# cambio_servicio) — la lógica vive en PR-D6.b.
class ServicioExtra < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de cambios al catálogo
  self.table_name = "servicios_extra"

  MONEDAS = %w[USD LPS].freeze

  validates :codigo, presence: true,
                     uniqueness: { case_sensitive: false },
                     format: { with: /\A[A-Z0-9_]+\z/, message: "solo mayúsculas, números o guion bajo" }
  validates :descripcion,  presence: true
  validates :costo,        presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :precio_venta, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :moneda,       inclusion: { in: MONEDAS }
  validates :minimo_monto,  numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :minimo_moneda, inclusion: { in: MONEDAS }, allow_nil: true

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }
  normalizes :moneda, with: ->(m) { m.to_s.upcase }
  normalizes :minimo_moneda, with: ->(m) { m.to_s.upcase.presence }

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :descripcion) }

  def to_s
    "#{codigo} — #{descripcion}"
  end

  def margen
    precio_venta - costo
  end

  # PR-10.a: el ISV se aplica UNA sola vez, al totalizar la pre-factura. Si
  # este servicio ya trae el impuesto adentro (`precio_incluye_isv`, que es el
  # default y lo que Yusef describió: "ya incluye ISV"), hay que meter el neto
  # a la línea — antes se metía el bruto y se le volvía a aplicar el 15%.
  def precio_venta_sin_isv
    return precio_venta.to_d unless precio_incluye_isv?

    (precio_venta.to_d / (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # ── Mínimo (PR-C6.12) ───────────────────────────────────────────────────
  #
  # Yusef, mostrando el CRUD del sistema viejo: "precio mínimo a cobrar, lo
  # tiene **obligado**". Y el retornado de Miami *es* un mínimo — "$5 es como
  # un precio mínimo que cobramos, porque son 5 dólares MÁS el trámite más la
  # llevada al correo".
  #
  # La moneda del mínimo va aparte de la del precio, igual que en `Tarifa`: el
  # flete se cotiza en dólares pero el piso vive en Lempiras, porque así lo
  # pone la competencia.

  def aplica_minimo?
    minimo_monto.present? && minimo_monto.to_d.positive?
  end

  # El piso, convertido a la moneda que se pide. `nil` cuando no hay mínimo.
  def minimo_monto_en(moneda_destino)
    return nil unless aplica_minimo?

    CurrencyAware.convertir(minimo_monto, de: minimo_moneda.presence || moneda, a: moneda_destino)
  end

  # El monto a cobrar por `cantidad` unidades, ya con el piso aplicado.
  # Devuelve el neto (sin ISV), que es lo que entra a la línea del documento.
  def cobro_para(cantidad = 1, en: moneda)
    unitario = CurrencyAware.convertir(precio_venta_sin_isv, de: moneda, a: en)
    subtotal = (unitario.to_d * cantidad.to_d).round(2, BigDecimal::ROUND_HALF_UP)

    piso = minimo_neto_en(en)
    return subtotal if piso.nil? || subtotal >= piso

    piso
  end

  # El mínimo **sin ISV**, para poder compararlo contra un subtotal neto.
  # Yusef habla del mínimo como precio final (los L.200 son con impuesto), así
  # que se le saca el ISV con el mismo criterio que a `precio_venta`.
  def minimo_neto_en(moneda_destino)
    bruto = minimo_monto_en(moneda_destino)
    return nil if bruto.nil?
    return bruto unless precio_incluye_isv?

    (bruto.to_d / (1 + IsvAware.rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  # Lo que Yusef escribe en el CRUD: el mínimo **con** impuesto. La columna
  # guarda lo mismo que él ve, y el neto se calcula al cobrar — al revés que
  # `Tarifa#minimo_monto_con_isv`, que guarda el neto, porque acá el flag
  # `precio_incluye_isv` ya dice si el número lo trae adentro.
  def minimo_label
    return nil unless aplica_minimo?
    "#{minimo_moneda.presence || moneda} #{format('%.2f', minimo_monto)}"
  end
end
