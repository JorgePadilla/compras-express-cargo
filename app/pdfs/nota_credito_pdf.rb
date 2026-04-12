class NotaCreditoPdf < ApplicationPdf
  def initialize(nota_credito)
    @nc    = nota_credito
    @venta = nota_credito.venta
    super()
  end

  private

  def build
    header
    titulo_documento("NOTA DE CREDITO", @nc.numero)

    text "Fecha: #{@nc.created_at.to_date}"
    text "Estado: #{@nc.estado.upcase}"
    text "Motivo: #{@nc.motivo.humanize}"
    text "Factura referenciada: #{@venta.numero}"
    move_down 5

    bloque_cliente(@nc.cliente)
    tabla_items(@nc.nota_credito_items)
    bloque_totales(
      subtotal: @nc.subtotal,
      impuesto: @nc.impuesto,
      total:    @nc.total,
      moneda:   @nc.moneda,
      tasa_cambio: @nc.tasa_cambio_aplicada
    )

    if @nc.notas.present?
      move_down 10
      text "Notas: #{@nc.notas}", size: 9, color: "666666"
    end

    footer_terminos
  end
end
