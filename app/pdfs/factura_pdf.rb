class FacturaPdf < ApplicationPdf
  def initialize(factura)
    @factura = factura
    super()
  end

  private

  def build
    header
    titulo = @factura.proforma? ? "PROFORMA" : "FACTURA"
    titulo_documento(titulo, @factura.numero)

    text "Fecha: #{I18n.l(@factura.created_at.to_date, format: :long)}" rescue text "Fecha: #{@factura.created_at.to_date}"
    text "Estado: #{@factura.estado.upcase}"
    text "Pre-Factura: #{@factura.pre_factura&.numero}" if @factura.pre_factura
    move_down 5

    bloque_cliente(@factura.cliente)
    tabla_items(@factura.factura_items)
    bloque_totales(
      subtotal: @factura.subtotal,
      impuesto: @factura.impuesto,
      total:    @factura.total,
      saldo:    @factura.saldo_pendiente,
      moneda:   @factura.moneda,
      tasa_cambio: @factura.tasa_cambio_aplicada
    )

    if @factura.notas.present?
      move_down 10
      text "Notas: #{sanitize_text(@factura.notas)}", size: 9, color: "666666"
    end

    footer_terminos
  end
end
