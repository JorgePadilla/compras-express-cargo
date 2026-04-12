class CotizacionPdf < ApplicationPdf
  def initialize(cotizacion)
    @ct = cotizacion
    super()
  end

  private

  def build
    header
    titulo_documento("COTIZACION", @ct.numero)

    text "Fecha: #{@ct.created_at.to_date}"
    text "Estado: #{@ct.estado.upcase}"
    text "Vigencia: #{@ct.vigencia_dias} dias (hasta #{@ct.fecha_vencimiento})" if @ct.fecha_vencimiento
    move_down 5

    bloque_cliente(@ct.cliente)
    tabla_items_cotizacion
    bloque_totales(
      subtotal: @ct.subtotal,
      impuesto: @ct.impuesto,
      total:    @ct.total,
      moneda:   @ct.moneda,
      tasa_cambio: @ct.tasa_cambio_aplicada
    )

    if @ct.notas.present?
      move_down 10
      text "Notas: #{@ct.notas}", size: 9, color: "666666"
    end

    if @ct.terminos.present?
      move_down 10
      text "Terminos y condiciones:", style: :bold, size: 9
      text @ct.terminos, size: 8, color: "666666"
    end

    footer_terminos
  end

  def tabla_items_cotizacion
    rows = [%w[Concepto Cantidad Precio Subtotal]]
    @ct.cotizacion_items.each do |item|
      qty = if item.peso_cobrar.present?
              "#{format('%.2f', item.peso_cobrar)} lb"
            else
              format("%.2f", item.cantidad || 1)
            end
      price = if item.precio_libra.present?
                format_money(item.precio_libra, @ct.moneda)
              else
                format_money(item.precio_unitario || 0, @ct.moneda)
              end
      rows << [item.concepto.to_s, qty, price, format_money(item.subtotal || 0, @ct.moneda)]
    end

    table(rows, header: true, width: bounds.width) do
      row(0).font_style = :bold
      row(0).background_color = "EEEEEE"
      columns(1..3).align = :right
      cells.padding = 6
      cells.borders = [:bottom]
      row(0).borders = [:bottom]
    end
    move_down 10
  end
end
