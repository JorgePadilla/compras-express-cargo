# PR-F2.2a · Fase 15. Anular una factura SAR (Art. 41).
#
#   Fiscal::AnularFactura.new(factura:, por:, autorizado_por:, pin:, motivo:).call
#
# Jorge (Q6, 2026-10-10): *pide PIN de supervisor (cuatro ojos, como las notas)
# y motivo; con cualquier pago ya no se anula: se corrige con nota de crédito*.
# El PIN, el rol que autoriza y los cuatro ojos los valida `Autorizacion`, que
# queda en la bitácora como «Factura anulada».
#
# La anulación pasa por la gema: la factura y su documento fiscal quedan
# ANULADOS con el motivo, el libro suma un asiento de anulación, y el número no
# se vuelve a usar. Las pre-facturas se sueltan (vuelven a `pendiente`, sin
# factura) para poder facturarlas bien — ❓ a confirmar con Jorge en F2.4, que
# es cuando esto tiene botón.
module Fiscal
  class AnularFactura
    def initialize(factura:, por:, autorizado_por:, pin:, motivo:)
      @factura = factura
      @por = por
      @autorizado_por = autorizado_por
      @pin = pin
      @motivo = motivo.to_s.strip
    end

    def call
      raise AnulacionRechazada, "hay que decir el motivo de la anulación" if @motivo.empty?

      autorizacion = Autorizacion.new(
        documento: @factura, accion: "anular_factura", solicitado_por: @por,
        autorizado_por: @autorizado_por, pin: @pin, motivo: @motivo,
        concepto: "#{@factura.numero} · #{@factura.cliente_nombre}", valor_anterior: @factura.total
      )
      raise AnulacionRechazada, autorizacion.errors.full_messages.to_sentence unless autorizacion.valid?

      ActiveRecord::Base.transaction do
        @factura.lock!
        raise AnulacionRechazada, "#{@factura.numero} ya está anulada" if @factura.anulada?
        if @factura.pagos_completados?
          raise AnulacionRechazada, "#{@factura.numero} ya tiene pagos: se corrige con una nota de crédito"
        end

        Fiscal.issuance(punto: @factura.punto_de_emision).annul(@factura.numero, reason: @motivo)
        autorizacion.save!
        PreFactura.where(factura_id: @factura.id).find_each do |pf|
          pf.update!(factura_id: nil, estado: "pendiente", facturado_at: nil)
        end
      end

      @factura.reload
    end
  end
end
