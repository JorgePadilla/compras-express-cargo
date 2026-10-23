require "test_helper"

# PR-A11Y.7 · Todo modal tiene nombre.
#
# Un `<dialog>` sin nombre se anuncia como «diálogo» y nada más: el lector de
# pantalla no dice si es «Problema», «Notas del cliente» o «Bajar la cantidad
# de cajas». El 2026-10-23 eran 32 de 36. El nombre sale del título del
# `ModalHeaderComponent` (`titulo_id:`) con `aria-labelledby` en el diálogo.
#
# Mira los `<dialog>` y los `div` con `role="dialog"`/`"alertdialog"`, y que
# el id al que apunta un `aria-labelledby` fijo exista en el mismo archivo:
# un nombre que apunta a nada es lo mismo que no tenerlo.
class DialogosConNombreTest < ActiveSupport::TestCase
  ARCHIVOS = Dir[Rails.root.join("app/{views,components}/**/*.erb")].freeze
  # Un tag de apertura, respetando las comillas: `data-action="cancel->x#y"`
  # lleva un `>` adentro.
  TAG = /<(?:dialog\b|[a-z]+\b(?=(?:[^>"']|"[^"]*"|'[^']*')*\brole="(?:alert)?dialog"))(?:[^>"']|"[^"]*"|'[^']*')*>/

  test "todo modal tiene nombre" do
    sin_nombre = modales.reject { |_, _, tag| tag.match?(/\baria-label(?:ledby)?=/) }

    assert_empty sin_nombre.map { |ruta, linea, _| "#{ruta}:#{linea}" }, <<~MSG
      Modal sin nombre: el lector de pantalla lo anuncia como «diálogo» a secas.
      Pasale `titulo_id: "algo-titulo"` al ModalHeaderComponent y
      `aria-labelledby="algo-titulo"` al diálogo (docs/07, «Estándar de pantalla»).
    MSG
  end

  test "el aria-labelledby apunta a algo que existe en el archivo" do
    rotos = modales.filter_map do |ruta, linea, tag|
      id = tag[/aria-labelledby="([^"<]+)"/, 1]
      next unless id

      src = File.read(Rails.root.join(ruta))
      "#{ruta}:#{linea} → #{id}" unless src.include?(%(titulo_id: "#{id}")) || src.include?(%(id="#{id}"))
    end

    assert_empty rotos, "aria-labelledby que apunta a un id que no está:\n#{rotos.join("\n")}"
  end

  private

  def modales
    @modales ||= ARCHIVOS.flat_map do |archivo|
      src = File.read(archivo).gsub(/<%#.*?%>/m) { |c| c.gsub(/[^\n]/, " ") }
      ruta = Pathname(archivo).relative_path_from(Rails.root).to_s
      src.to_enum(:scan, TAG).map do
        m = Regexp.last_match
        [ ruta, src[0...m.begin(0)].count("\n") + 1, m[0] ]
      end
    end
  end
end
