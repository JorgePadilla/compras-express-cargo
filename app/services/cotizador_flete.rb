# PR-10.b: cotiza el flete de un paquete que todavía no existe.
#
# Yusef (2026-08-02) sobre Entrega Personal: "hay que agregarle para poder
# [ver] el valor a pagar... de acuerdo a la tarifa que tiene el cliente
# asignado" y "valor a pagar → en dólares y lempiras".
#
# Es solo display: no persiste nada. La verdad del cobro sigue naciendo en
# Pre-Factura. Por eso este PORO replica paso a paso lo que hace
# `PreFactura.build_from_paquetes` — hay un test que verifica que la
# cotización y la factura den lo mismo para el mismo paquete.
class CotizadorFlete
  MONEDA_DOCUMENTO = "LPS".freeze

  Resultado = Struct.new(
    :peso_cobrar, :peso_facturado, :vlbs,
    :precio_libra, :subtotal, :impuesto, :total,
    :aplico_minimo, :tarifa, :tasa, :moneda,
    keyword_init: true
  ) do
    def tarifa_encontrada? = tarifa.present?

    # El mismo monto en la otra moneda, para el "en dólares y lempiras".
    def en_usd(monto)
      CurrencyAware.convertir(monto, de: moneda, a: "USD", tasa: tasa)
    end
  end

  def self.call(...) = new(...).call

  def initialize(tipo_envio:, cliente: nil, proveedor: nil, sucursal: nil,
                 peso: nil, alto: nil, largo: nil, ancho: nil)
    @tipo_envio = tipo_envio
    @cliente    = cliente
    @proveedor  = proveedor
    @sucursal   = sucursal
    @peso       = peso.to_d
    @alto       = alto
    @largo      = largo
    @ancho      = ancho
  end

  def call
    tasa = CurrencyAware.tasa_vigente
    tarifa = Tarifa.resolver(
      tipo_envio: @tipo_envio, peso: peso_cobrar,
      cliente: @cliente, proveedor: @proveedor, sucursal: @sucursal
    )

    if tarifa
      cobro    = tarifa.cobro_para(peso_cobrar)
      precio   = convertir(tarifa.precio_libra, tarifa.moneda, tasa)
      peso_fac = cobro[:peso_facturado]
      subtotal = if cobro[:aplico_minimo]
        convertir(cobro[:subtotal], cobro[:moneda], tasa)
      else
        (peso_fac * precio).round(2, BigDecimal::ROUND_HALF_UP)
      end
      aplico = cobro[:aplico_minimo]
    else
      # Mismo fallback que la pre-factura cuando no hay tarifa cargada.
      precio_origen = @cliente&.categoria_precio&.precio_para(@tipo_envio) ||
                      @tipo_envio&.precio_libra || BigDecimal("0")
      precio   = convertir(precio_origen, "USD", tasa)
      peso_fac = peso_cobrar
      subtotal = (peso_fac * precio).round(2, BigDecimal::ROUND_HALF_UP)
      aplico   = false
    end

    impuesto = (subtotal * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP)

    Resultado.new(
      peso_cobrar: peso_cobrar, peso_facturado: peso_fac, vlbs: vlbs,
      precio_libra: precio, subtotal: subtotal, impuesto: impuesto,
      total: (subtotal + impuesto).round(2, BigDecimal::ROUND_HALF_UP),
      aplico_minimo: aplico, tarifa: tarifa, tasa: tasa, moneda: MONEDA_DOCUMENTO
    )
  end

  # Mismo criterio que `Paquete#calculate_peso_cobrar`: el mayor entre el peso
  # real y el volumétrico redondeado a ½ libra.
  def peso_cobrar
    @peso_cobrar ||= [ @peso, vlbs ].max
  end

  def vlbs
    @vlbs ||= begin
      in3 = VolumetricoCalculator.pulgadas_cubicas(@alto, @largo, @ancho)
      in3.positive? ? BigDecimal(VolumetricoCalculator.vlbs(in3).to_s) : BigDecimal("0")
    end
  end

  private

  def convertir(monto, desde, tasa)
    CurrencyAware.convertir(monto, de: desde.to_s.presence || MONEDA_DOCUMENTO,
                                   a: MONEDA_DOCUMENTO, tasa: tasa)
  end
end
