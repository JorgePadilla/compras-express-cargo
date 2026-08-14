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
    :aplico_minimo, :tarifa, :tasa, :moneda, :sin_tarifa,
    keyword_init: true
  ) do
    def tarifa_encontrada? = tarifa.present?

    # El mismo monto en la otra moneda, para el "en dólares y lempiras".
    def en_usd(monto)
      CurrencyAware.convertir(monto, de: moneda, a: "USD", tasa: tasa)
    end
  end

  def self.call(...) = new(...).call

  # `cajas` cotiza un envío de varios bultos: una lista de hashes con `peso`,
  # `alto`, `largo` y `ancho`. Cuando viene, las medidas sueltas se ignoran.
  def initialize(tipo_envio:, cliente: nil, proveedor: nil, sucursal: nil,
                 peso: nil, alto: nil, largo: nil, ancho: nil, cajas: nil)
    @tipo_envio = tipo_envio
    @cliente    = cliente
    @proveedor  = proveedor
    @sucursal   = sucursal
    @peso       = peso.to_d
    @alto       = alto
    @largo      = largo
    @ancho      = ancho
    @cajas      = Array(cajas).reject(&:blank?)
  end

  def call
    return call_por_cajas if @cajas.any?

    call_de_un_bulto
  end

  # ── El envío de varias cajas ──────────────────────────────────────────────
  #
  # PR-C7.17. Se cotiza **caja por caja y se suma**, no se suman las libras para
  # cotizar una sola vez. No es un detalle: es lo que hace `PreFactura`.
  #
  # `PreFactura#build_from_paquetes` recorre `paquetes.each` y arma **una línea
  # por caja**, y cada una resuelve su propio escalón y compara contra su propio
  # mínimo. Con las cajas del ejemplo de `A9-03` —que cobran 5, 9 y 163 lb en
  # CER— la diferencia es real:
  #
  #   caja por caja (lo que factura hoy) ... $633.50
  #   envío entero (177 lb en un escalón) .. $619.50
  #
  # Cotizar el envío entero le mostraría al operario **$14 menos de lo que la
  # factura le va a cobrar al cliente**, que es justo la divergencia que este PR
  # viene a cerrar.
  #
  # Si mañana se decide cobrar por envío, se cambia acá **y** en `PreFactura`, no
  # en uno solo. Está abierto como `RP-41`.
  def call_por_cajas
    partes = @cajas.map { |c| self.class.call(**contexto, **medidas_de(c)) }

    subtotal = partes.sum { |p| p.subtotal }
    impuesto = (subtotal * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP)
    precios  = partes.map(&:precio_libra).uniq

    Resultado.new(
      peso_cobrar:    partes.sum { |p| p.peso_cobrar },
      peso_facturado: partes.sum { |p| p.peso_facturado },
      vlbs:           partes.sum { |p| p.vlbs },
      # Con las cajas en escalones distintos no hay "un" precio por libra que
      # mostrar; el panel lo pinta como "varía" en vez de mentir con el de una.
      precio_libra:   (precios.size == 1 ? precios.first : nil),
      subtotal:       subtotal,
      impuesto:       impuesto,
      total:          (subtotal + impuesto).round(2, BigDecimal::ROUND_HALF_UP),
      aplico_minimo:  partes.any?(&:aplico_minimo),
      tarifa:         partes.first&.tarifa,
      tasa:           CurrencyAware.tasa_vigente,
      moneda:         MONEDA_DOCUMENTO,
      sin_tarifa:     partes.any?(&:sin_tarifa)
    )
  end

  def contexto
    { tipo_envio: @tipo_envio, cliente: @cliente, proveedor: @proveedor, sucursal: @sucursal }
  end

  def medidas_de(caja)
    c = caja.respond_to?(:to_unsafe_h) ? caja.to_unsafe_h : caja
    c = c.symbolize_keys
    { peso: c[:peso], alto: c[:alto], largo: c[:largo], ancho: c[:ancho] }
  end

  def call_de_un_bulto
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
      # A7-25. Acá vivía el mismo fallback a la tabla vieja que tenía la
      # pre-factura, y con el mismo problema: cotizaba con un precio que no es
      # el que se va a cobrar.
      #
      # A diferencia de la pre-factura, esto es **display** — la pantalla de
      # etiquetar lo muestra mientras el operario captura. Así que no corta:
      # devuelve cero y avisa, para que el vacío se lea como "falta cargar la
      # tarifa" y no como "es gratis".
      precio   = BigDecimal("0")
      peso_fac = peso_cobrar
      subtotal = BigDecimal("0")
      aplico   = false
    end

    impuesto = (subtotal * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP)

    Resultado.new(
      peso_cobrar: peso_cobrar, peso_facturado: peso_fac, vlbs: vlbs,
      precio_libra: precio, subtotal: subtotal, impuesto: impuesto,
      total: (subtotal + impuesto).round(2, BigDecimal::ROUND_HALF_UP),
      aplico_minimo: aplico, tarifa: tarifa, tasa: tasa, moneda: MONEDA_DOCUMENTO,
      sin_tarifa: tarifa.nil?
    )
  end

  # Mismo criterio que `Paquete#calculate_peso_cobrar` — literalmente el mismo
  # método desde PR-C6.41, para que la cotización y la factura no se separen.
  def peso_cobrar
    @peso_cobrar ||= VolumetricoCalculator.entre_peso_y_vlbs(
      @peso, vlbs, solo_volumetrico: @cliente&.cobra_solo_volumetrico?(@tipo_envio)
    )
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
