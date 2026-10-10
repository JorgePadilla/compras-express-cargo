require "test_helper"

# Un botón de imprimir abre la hoja en pestaña nueva con `?print=true`.
#
# Ese parámetro es todo el comportamiento: la hoja (`layouts/print` y
# `layouts/_etiqueta_autoprint`) abre el diálogo de impresión sola al cargar, y
# cuando se imprime —o se cancela— se cierra y el operario vuelve a la pantalla
# donde estaba. Sin él la pestaña queda abierta mostrando la etiqueta, y hay que
# buscar el botón de imprimir y cerrarla a mano.
#
# Jorge, 2026-10-10, sobre el ícono de reimprimir de /medicion/volumenes: *"this
# imprimir is not working as print preview and than after print come back to
# the same window, this is a behaviour we want in all the app"*. Era el único
# que lo había olvidado; el resto de los botones lo pasaban de memoria.
class ImprimirSeCierraSoloTest < ActiveSupport::TestCase
  BOTON = /\b(RowAction|Button)Component\.new\(/
  # El ícono de reimprimir de una fila, o un botón con la impresora que abre
  # pestaña nueva.
  DE_IMPRIMIR = /action:\s*:print\b|icon:\s*"printer"/
  CON_PRINT = /print:\s*(true|"true")/

  # Abren una pantalla para **elegir** qué imprimir, no la hoja: ahí todavía no
  # hay nada que mandar a la impresora.
  ELEGIR_ANTES = [
    "reimprimir_etiquetas_paquete_path" # «Re-imprimir Etiquetas Miami»: elige cuáles
  ].freeze

  test "todo botón de imprimir en pestaña nueva pasa print: true" do
    ofensores = []

    Dir.glob(Rails.root.join("app/{views,components}/**/*.erb")).sort.each do |archivo|
      texto = File.read(archivo)
      texto.to_enum(:scan, BOTON).each do
        inicio = Regexp.last_match.begin(0)
        # La llamada entera: hasta el cierre del tag o el `do` del bloque.
        llamada = texto[inicio, 600][/\A.*?(%>|\)\s*do\b|\)\)\s*\{)/m] || texto[inicio, 600]
        next unless llamada.match?(DE_IMPRIMIR)
        next unless llamada.include?("_blank") || llamada.include?("action: :print")
        next if llamada.match?(CON_PRINT)
        next if ELEGIR_ANTES.any? { |ruta| llamada.include?(ruta) }

        ruta = Pathname.new(archivo).relative_path_from(Rails.root)
        linea = texto[0, inicio].count("\n") + 1
        ofensores << "  #{ruta}:#{linea}  #{llamada.lines.first.strip}"
      end
    end

    assert_empty ofensores, <<~MSG
      Estos botones abren la hoja en pestaña nueva **sin** `print: true`: no sale
      el diálogo de impresión y la pestaña queda abierta en lugar de volver a la
      pantalla. Pasale el parámetro a la ruta:

        etiqueta_bulto_medicion_path(bulto)  →  etiqueta_bulto_medicion_path(bulto, print: true)

      #{ofensores.join("\n")}
    MSG
  end
end
