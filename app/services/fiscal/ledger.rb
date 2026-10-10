# PR-F1.2 · Fase 15. El libro de la gema `invoicehn` (Art. 53 num. 1 y 5), en
# `asientos_fiscales`: una fila por emisión o anulación, que la base no deja
# cambiar ni borrar (D2 de FISCAL.md).
#
# `entries` devuelve las mismas llaves que `Invoicehn::Ledger::JsonlLedger`, que
# es lo que lee la exportación a la SAR (F3). Un test las compara contra el
# libro de la gema con el mismo documento.
module Fiscal
  class Ledger
    # La gema no traga errores del libro: si esto tira, deshace la emisión. En
    # un savepoint, para que un error de la base acá no deje la transacción
    # abortada y la gema pueda borrar el documento que acaba de guardar.
    def record(invoice, event: :emision)
      numero = invoice.correlative.to_s
      punto, = Fiscal.punto_y_tipo(invoice.correlative.identifier)

      AsientoFiscal.transaction(requires_new: true) do
        AsientoFiscal.create!(
          evento: event.to_s, tipo_documento: invoice.document_type, numero: numero,
          punto_de_emision: punto, documento: DocumentoFiscal.find_by(numero: numero),
          referencia: invoice.reference&.correlative&.to_s,
          fecha_emision: invoice.issue_date, cai: invoice.authorization.cai,
          # `customer.to_s`, como el libro de la gema: nombre y RTN, o
          # «CONSUMIDOR FINAL».
          cliente_nombre: invoice.customer.to_s, cliente_rtn: invoice.customer.rtn&.to_s,
          moneda: invoice.currency,
          subtotal: invoice.subtotal.amount, descuento: invoice.discount.amount,
          isv: invoice.isv_total.amount, total: invoice.total.amount,
          estado: invoice.status, payload: invoice.to_h, usuario: Current.user
        )
      end
      invoice
    end

    def entries(from: nil, to: nil)
      asientos = AsientoFiscal.order(:registrado_at, :id)
      asientos = asientos.where(fecha_emision: from..) if from
      asientos = asientos.where(fecha_emision: ..to) if to
      asientos.map { |a| entrada(a) }
    end

    private

    def entrada(asiento)
      {
        "recorded_at" => asiento.registrado_at.utc.iso8601,
        "event" => asiento.evento,
        "correlative" => asiento.numero,
        "document_type" => asiento.tipo_documento,
        "reference" => asiento.referencia,
        "issue_date" => asiento.fecha_emision.iso8601,
        "cai" => asiento.cai,
        "customer" => asiento.cliente_nombre,
        "customer_rtn" => asiento.cliente_rtn,
        "currency" => asiento.moneda,
        "subtotal" => monto(asiento.subtotal, asiento.moneda),
        "discount" => monto(asiento.descuento, asiento.moneda),
        "isv" => monto(asiento.isv, asiento.moneda),
        "total" => monto(asiento.total, asiento.moneda),
        "status" => asiento.estado
      }
    end

    # El mismo formato que `Money#to_h`: dos decimales, como texto.
    def monto(valor, moneda)
      Invoicehn::Money.new(valor, moneda).to_h["amount"]
    end
  end
end
