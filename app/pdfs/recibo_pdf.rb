class ReciboPdf < ApplicationPdf
  def initialize(recibo)
    @recibo = recibo
    @venta  = recibo.venta
    @pago   = recibo.pago
    super()
  end

  private

  def build
    header
    titulo_documento("RECIBO DE PAGO", @recibo.numero)

    text "Fecha: #{@recibo.created_at.to_date}"
    text "Forma de pago: #{@recibo.forma_pago}"
    move_down 5

    bloque_cliente(@recibo.cliente)

    move_down 10
    text "Factura relacionada:", style: :bold
    text "#{@venta.numero} - Total: #{format_money(@venta.total, @venta.moneda)}"
    move_down 10

    data = [
      ["Monto recibido:", format_money(@recibo.monto, @recibo.moneda)],
      ["Saldo pendiente venta:", format_money(@venta.saldo_pendiente, @venta.moneda)]
    ]
    table(data, width: bounds.width) do
      cells.padding = 6
      cells.borders = [:top, :bottom]
      column(0).font_style = :bold
      column(1).align = :right
    end

    if @pago.notas.present?
      move_down 10
      text "Notas: #{@pago.notas}", size: 9, color: "666666"
    end

    footer_terminos
  end
end
