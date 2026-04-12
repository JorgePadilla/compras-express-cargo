class VentaPdf < ApplicationPdf
  def initialize(venta)
    @venta = venta
    super()
  end

  private

  def build
    header
    titulo_documento("FACTURA", @venta.numero)

    text "Fecha: #{I18n.l(@venta.created_at.to_date, format: :long)}" rescue text "Fecha: #{@venta.created_at.to_date}"
    text "Estado: #{@venta.estado.upcase}"
    text "Pre-Factura: #{@venta.pre_factura&.numero}" if @venta.pre_factura
    move_down 5

    bloque_cliente(@venta.cliente)
    tabla_items(@venta.venta_items)
    bloque_totales(
      subtotal: @venta.subtotal,
      impuesto: @venta.impuesto,
      total:    @venta.total,
      saldo:    @venta.saldo_pendiente,
      moneda:   @venta.moneda
    )

    if @venta.notas.present?
      move_down 10
      text "Notas: #{@venta.notas}", size: 9, color: "666666"
    end

    footer_terminos
  end
end
