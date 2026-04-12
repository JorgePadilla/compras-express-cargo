require "prawn"
require "prawn/table"

class ApplicationPdf
  include Prawn::View

  FONT_REGULAR = Rails.root.join("vendor/fonts/DejaVuSans.ttf")
  FONT_BOLD    = Rails.root.join("vendor/fonts/DejaVuSans-Bold.ttf")

  def initialize
    @document = Prawn::Document.new(page_size: "LETTER", margin: [40, 40, 40, 40])
    setup_fonts
  end

  def render
    build
    @document.render
  end

  def render_file(path)
    build
    @document.render_file(path)
  end

  private

  def setup_fonts
    if FONT_REGULAR.exist? && FONT_BOLD.exist?
      font_families.update(
        "DejaVuSans" => {
          normal: FONT_REGULAR.to_s,
          bold:   FONT_BOLD.to_s
        }
      )
      font "DejaVuSans"
    end
  end

  def empresa
    @empresa ||= Empresa.instance
  end

  def header
    if empresa.logo.attached? && (path = empresa.logo_file_path) && File.exist?(path)
      begin
        image path, width: 120, position: :left
      rescue => _e
        # Ignora logos invalidos
      end
    end
    move_down 5
    text empresa.nombre, size: 14, style: :bold
    text "RTN: #{empresa.rtn}" if empresa.rtn.present?
    text empresa.direccion if empresa.direccion.present?
    if empresa.telefono.present? || empresa.email_contacto.present?
      linea = [empresa.telefono, empresa.email_contacto].compact_blank.join(" - ")
      text linea
    end
    move_down 10
    stroke_horizontal_rule
    move_down 10
  end

  def titulo_documento(titulo, numero)
    text titulo, size: 18, style: :bold, align: :center
    text "No. #{numero}", size: 12, align: :center
    move_down 10
  end

  def bloque_cliente(cliente)
    move_down 10
    text "Cliente:", style: :bold
    text "#{cliente.codigo} - #{cliente.nombre_completo}"
    text cliente.direccion if cliente.direccion.present?
    text "Tel: #{cliente.telefono}" if cliente.telefono.present?
    text "Email: #{cliente.email}" if cliente.email.present?
    move_down 10
  end

  def tabla_items(items, columnas: %w[Concepto Peso Precio/lb Subtotal])
    rows = [columnas]
    items.each do |item|
      rows << [
        sanitize_text(item.concepto),
        item.peso_cobrar.present? ? format("%.2f", item.peso_cobrar) : "-",
        item.precio_libra.present? ? format("%.2f", item.precio_libra) : "-",
        format_money(item.subtotal || 0)
      ]
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

  def bloque_totales(subtotal:, impuesto:, total:, saldo: nil, moneda: "LPS", tasa_cambio: nil)
    data = [
      ["Subtotal:", format_money(subtotal, moneda)],
      ["ISV (#{(empresa.isv_rate * 100).to_i}%):", format_money(impuesto, moneda)],
      ["Total:", format_money(total, moneda)]
    ]
    data << ["Saldo Pendiente:", format_money(saldo, moneda)] if saldo
    data << ["Tasa de cambio:", "#{tasa_cambio} LPS/USD"] if moneda == "USD" && tasa_cambio.present?

    bounding_box([bounds.width - 250, cursor], width: 250) do
      table(data, width: 250) do
        cells.padding = 4
        cells.borders = []
        column(0).font_style = :bold
        column(1).align = :right
        row(data.length - 1).font_style = :bold if data.length > 1
      end
    end
    move_down 10
  end

  def footer_terminos
    return unless empresa.terminos_factura.present?

    move_down 20
    text empresa.terminos_factura, size: 8, color: "666666", align: :center
  end

  def sanitize_text(value)
    ActionController::Base.helpers.strip_tags(value.to_s)
  end

  def format_money(amount, moneda = "LPS")
    value = ActionController::Base.helpers.number_with_delimiter(format("%.2f", amount.to_f))
    "#{moneda} #{value}"
  end

  def build
    raise NotImplementedError, "#{self.class} must implement #build"
  end
end
