# PR-F2.1 · Fase 15 (D4 de FISCAL.md): los totales de **todo** documento de
# cobro —pre-factura, venta, notas, cotización— salen de la gema `invoicehn`
# (`TaxSummary`), por un solo adaptador. La factura SAR que viene en F2.2 va a
# imprimir el ISV de la gema; si la pre-factura lo calculara por su cuenta, la
# pre-factura y la factura podrían no coincidir en un centavo.
#
# Lo que NO cambia: la cadena de cobro (redondeo → escalón → mínimo) sigue en
# `PreFactura`; acá llega cada línea con su subtotal **ya cobrado** y redondeado.
# La regla del contador sigue siendo la misma: half-up al segundo decimal (la
# gema lo llama `round_statutory`, Ley del ISV Art. 9).
#
# D3 · Cada línea entra con `quantity: 1` y `unit_price:` igual a su subtotal.
# Con `quantity: peso` y `unit_price: precio_libra` la gema multiplicaría a
# precisión completa y redondearía la SUMA, no cada línea: dos líneas de
# 1.5 lb × 121.95 dan 182.925 cada una → hoy 182.93 + 182.93 = 365.86, y la
# gema daría 365.85. El subtotal de la línea es el número que el cliente ve
# impreso; el total tiene que salir de esos números.
#
# Equivalencia byte a byte con la fórmula de antes: `test/services/fiscal/
# totales_equivalencia_test.rb`.
module Fiscal
  module Totales
    # La app dice LPS desde siempre (`CurrencyAware::MONEDAS`); la gema usa el
    # código ISO, HNL. La traducción vive solo acá.
    MONEDA_GEMA = { "LPS" => "HNL", "USD" => "USD" }.freeze

    # La gema exige descripción (Art. 11 num. 1 lit. d). Para los totales no
    # importa —el `before_save` corre después de validar `concepto`—, pero la
    # vista previa (`vista_previa`, `reabrir_json_de`) suma líneas sin validar,
    # y ahí una línea sin concepto no puede tumbar la pantalla.
    SIN_DESCRIPCION = "—".freeze

    # `items`: las líneas vivas (el llamador ya sacó las
    # `marked_for_destruction?`). Cada una responde `subtotal`, `concepto` y
    # `tratamiento_fiscal`; `descuento_monto` solo si el modelo lo tiene
    # (pre-factura y venta).
    #
    # Devuelve BigDecimal, con los nombres de la app: `subtotal` es el BRUTO
    # (la columna `subtotal` de los documentos), no el `subtotal` de la gema,
    # que es la base después del descuento.
    def self.calcular(items, moneda:)
      moneda_gema = MONEDA_GEMA.fetch(moneda.to_s)
      lineas = Array(items).map { |item| linea(item, moneda_gema) }
      resumen = Invoicehn::TaxSummary.new(lineas, currency: moneda_gema)

      {
        subtotal: resumen.gross.amount,
        descuento: resumen.discount.amount,
        base: resumen.subtotal.amount,
        impuesto: resumen.isv_total.amount,
        total: resumen.total.amount,
        buckets: resumen.present_buckets,
        lineas: lineas
      }
    end

    def self.linea(item, moneda_gema)
      Invoicehn::LineItem.new(
        description: item.concepto.presence || SIN_DESCRIPCION,
        quantity: 1,
        unit_price: Invoicehn::Money.new(monto(item.subtotal), moneda_gema),
        discount: Invoicehn::Money.new(monto(item.try(:descuento_monto)), moneda_gema),
        treatment: Invoicehn::TaxTreatment.fetch(item.tratamiento_fiscal)
      )
    end

    # La gema rechaza Float (y hace bien). Las columnas decimales ya vienen en
    # BigDecimal; `nil` —una línea recién armada sin subtotal— suma cero, como
    # el `.to_d` de la fórmula de antes.
    def self.monto(valor)
      case valor
      when nil then BigDecimal("0")
      when BigDecimal then valor
      else BigDecimal(valor.to_s)
      end
    end

    private_class_method :linea, :monto
  end
end
