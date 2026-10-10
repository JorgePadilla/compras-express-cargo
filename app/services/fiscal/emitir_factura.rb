# PR-F2.2a · Fase 15. Factura una o más pre-facturas con número SAR.
#
#   Fiscal::EmitirFactura.new(pre_facturas: [pf], por: user).call  # => Factura
#
# Dormida: ninguna pantalla la llama (el corte es F2.4) y `PreFactura#facturar!`
# sigue armando la `Venta` de siempre. Recibe una lista y no una sola porque
# A7-32 (una factura por varias pre-facturas) está preguntado (Q4); hoy la
# llamada natural es con una.
#
# ── El orden de los candados ─────────────────────────────────────────────
#
# Pre-facturas (por id) → correlativo del punto → cliente. Las pre-facturas
# primero, como `anular!` y `GuardarPreFacturaAuditada`: así dos personas
# facturando la misma pre-factura no llegan a pedir número las dos. El
# correlativo lo toma la gema (`Fiscal::Sequence#allocate`) y el cliente la
# Factura al crearse, adentro de ese bloque.
#
# ── Lo que frena, y cuándo ───────────────────────────────────────────────
#
# Antes del correlativo, sin consumir nada: quien factura sin sucursal o sin
# punto activo (Q5, `SinPuntoDeEmision`), pre-facturas ya facturadas, anuladas,
# consolidando, de clientes o monedas distintas, o con una línea sin concepto
# (Art. 11 num. 1 lit. d; `PreFacturasNoFacturables`).
#
# Adentro del bloque del correlativo, que se deshace entero: la gema que no
# valida (`Invoicehn::ComplianceError`), sin CAI que cubra el número
# (`Invoicehn::NoAuthorization`), y el tripwire de totales (`TotalesNoCuadran`):
# si la gema suma otra cosa que las pre-facturas, no sale.
module Fiscal
  class EmitirFactura
    # Q7 (abierta): la tasa es la fija del admin (`/tasa_cambio`), no la del
    # BCH. El Art. 11 pide la vigente a la fecha y no nombra la fuente.
    FUENTE_DE_LA_TASA = "Tasa fija de Compras Express Cargo".freeze

    def initialize(pre_facturas:, por:)
      @ids = Array(pre_facturas).map { |pf| pf.is_a?(PreFactura) ? pf.id : pf }.uniq
      @por = por
    end

    def call
      punto = punto_de_emision!

      ActiveRecord::Base.transaction do
        pre_facturas = PreFactura.where(id: @ids).order(:id).lock.to_a
        items = validar!(pre_facturas)
        factura = construir(pre_facturas, items, punto)

        Fiscal.issuance(punto: punto, borrador: factura).issue(
          customer: ClienteFiscal.para(factura.cliente),
          line_items: Totales.calcular(items, moneda: factura.moneda)[:lineas],
          identifier: punto.identificador(Factura::TIPO),
          currency: Totales::MONEDA_GEMA.fetch(factura.moneda),
          exchange_rate: tasa(pre_facturas.first)
        )

        # Sin el `belongs_to` en PreFactura: ese modelo es de F2.1 en paralelo.
        # La columna alcanza para que no se vuelva a facturar.
        pre_facturas.each do |pf|
          pf.update!(factura_id: factura.id, estado: "facturado", facturado_at: Time.current)
        end
        factura
      end
    end

    private

    def punto_de_emision!
      sucursal = @por&.sucursal
      raise SinPuntoDeEmision, "#{@por&.nombre || 'Quien factura'} no tiene sucursal asignada" if sucursal.nil?

      punto = sucursal.punto_de_emision
      raise SinPuntoDeEmision, "#{sucursal.nombre} no tiene punto de emisión" if punto.nil?
      raise SinPuntoDeEmision, "el punto de emisión de #{sucursal.nombre} está inactivo" unless punto.activo?

      punto
    end

    def validar!(pre_facturas)
      no_facturables!("no se encontraron todas las pre-facturas") if pre_facturas.size != @ids.size

      pre_facturas.each do |pf|
        no_facturables!("#{pf.numero} está #{pf.estado}") if pf.facturado? || pf.anulado?
        no_facturables!("#{pf.numero} ya tiene factura") if pf.factura_id.present?
        if (motivo = pf.motivo_para_no_facturar)
          no_facturables!("#{pf.numero}: #{motivo}")
        end
      end
      no_facturables!("son de clientes distintos") if pre_facturas.map(&:cliente_id).uniq.size > 1
      no_facturables!("están en monedas distintas") if pre_facturas.map(&:moneda).uniq.size > 1

      items = pre_facturas.flat_map { |pf| pf.pre_factura_items.order(:id).to_a }
      no_facturables!("no tienen líneas") if items.empty?

      # Art. 11 num. 1 lit. d: la descripción de cada línea va impresa. La gema
      # también lo exige; acá se dice cuál, antes de pedir número.
      sin_concepto = items.select { |i| i.concepto.to_s.strip.empty? }
      if sin_concepto.any?
        no_facturables!("hay #{sin_concepto.size} línea(s) sin concepto (Art. 11): #{sin_concepto.map(&:id).join(', ')}")
      end
      items
    end

    def construir(pre_facturas, items, punto)
      Factura.new(
        punto_de_emision: punto, cliente: pre_facturas.first.cliente, creado_por: @por,
        moneda: pre_facturas.first.moneda, total_esperado: pre_facturas.sum(&:total)
      ).tap do |factura|
        items.each do |item|
          factura.factura_items.build(
            pre_factura_item: item, paquete_id: item.paquete_id, bulto_id: item.bulto_id,
            concepto: item.concepto, peso_cobrar: item.peso_cobrar, precio_libra: item.precio_libra,
            subtotal: item.subtotal, descuento_monto: item.descuento_monto,
            tratamiento: item.tratamiento_fiscal.to_s
          )
        end
      end
    end

    # Art. 11, párrafo final: en otra moneda, la tasa vigente a la fecha.
    def tasa(pre_factura)
      return nil unless pre_factura.moneda == "USD"

      Invoicehn::ExchangeRate.new(rate: pre_factura.tasa_cambio_aplicada || CurrencyAware.tasa_vigente,
                                  date: Fiscal.hoy, currency: "USD", source: FUENTE_DE_LA_TASA)
    end

    def no_facturables!(motivo)
      raise PreFacturasNoFacturables, motivo
    end
  end
end
