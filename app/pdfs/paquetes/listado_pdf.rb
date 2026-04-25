module Paquetes
  class ListadoPdf < ApplicationPdf
    def initialize(paquetes, titulo: "Listado de Paquetes")
      @paquetes = paquetes.to_a
      @titulo = titulo
      @document = Prawn::Document.new(page_size: "LETTER", page_layout: :landscape, margin: [ 30, 30, 30, 30 ])
      setup_fonts
    end

    private

    def build
      text @titulo, size: 14, style: :bold
      text "Generado: #{Time.current.strftime("%d/%m/%Y %H:%M")} · Total: #{@paquetes.size} paquete(s)", size: 9, color: "666666"
      move_down 10

      if @paquetes.empty?
        text "Sin resultados.", size: 10, color: "999999"
        return
      end

      rows = [ headers ] + @paquetes.map { |p| row_for(p) }
      table(rows,
            header: true,
            width: bounds.width,
            cell_style: { size: 7, padding: [ 3, 4 ], border_width: 0.3 }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "1B2559"
        t.row(0).text_color = "FFFFFF"
        t.cells.borders = [ :bottom ]
        t.columns(0..-1).border_color = "DDDDDD"
      end
    end

    def headers
      [
        "F. Recibido", "F. Disponible", "N° Recepción", "Tracking",
        "Cliente", "Estado", "T.E.", "Cons.", "Contenido"
      ]
    end

    def row_for(paquete)
      [
        paquete.fecha_recibido_miami&.strftime("%d/%m/%Y") || paquete.created_at.strftime("%d/%m/%Y"),
        paquete.fecha_disponible&.strftime("%d/%m/%Y") || "—",
        paquete.numero_recepcion.presence || paquete.guia,
        truncate(paquete.tracking, 22),
        "#{paquete.cliente.codigo} · #{truncate(paquete.cliente.nombre_completo, 28)}",
        paquete.estado.humanize,
        paquete.tipo_envio&.codigo&.upcase || "—",
        paquete.consolidado? ? "Sí" : "—",
        truncate(paquete.descripcion.to_s, 30)
      ]
    end

    def truncate(str, max)
      s = str.to_s
      s.length > max ? "#{s[0, max - 1]}…" : s
    end
  end
end
