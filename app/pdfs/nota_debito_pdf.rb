class NotaDebitoPdf < ApplicationPdf
  def initialize(nota_debito)
    @nd    = nota_debito
    @venta = nota_debito.venta
    super()
  end

  private

  def build
    header
    titulo_documento("NOTA DE DEBITO", @nd.numero)

    text "Fecha: #{@nd.created_at.to_date}"
    text "Estado: #{@nd.estado.upcase}"
    text "Motivo: #{@nd.motivo.humanize}"
    text "Factura referenciada: #{@venta.numero}"
    move_down 5

    bloque_cliente(@nd.cliente)
    tabla_items(@nd.nota_debito_items)
    bloque_totales(
      subtotal: @nd.subtotal,
      impuesto: @nd.impuesto,
      total:    @nd.total,
      moneda:   @nd.moneda,
      tasa_cambio: @nd.tasa_cambio_aplicada
    )

    if @nd.notas.present?
      move_down 10
      text "Notas: #{sanitize_text(@nd.notas)}", size: 9, color: "666666"
    end

    footer_terminos
  end
end
