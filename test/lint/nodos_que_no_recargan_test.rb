require "test_helper"

# En un system test, `first(...)` devuelve un nodo que **no se recarga**.
#
# Capybara le guarda la query al nodo que devuelve `find` y la vuelve a correr
# cuando lo encuentra viejo; a los de `first` no. Así que `first(...).click`
# ubica el elemento en un viaje y lo aprieta en el siguiente, y si la página se
# reemplazó en el medio revienta con `StaleElementReferenceError`.
#
# ── Por qué pasa, y por qué solo en CI ──────────────────────────────────────
#
# Por el **preview de caché de Turbo**. Un link normal a una pantalla ya
# visitada pinta al instante el snapshot cacheado (`<html data-turbo-preview>`)
# y reemplaza el body cuando llega la respuesta fresca. Un `assert_selector`
# después de navegar pasa contra el preview, así que no protege de nada: el
# nodo que se ubicó ahí muere en el swap.
#
# En local la respuesta vuelve tan rápido que la ventana no existe. En CI sí, y
# `flujo_del_manifiesto_test` se caía ~2 de cada 3 corridas por esto. Se
# reprodujo a propósito con `demorar("/manifiestos/")` y forzando el swap entre
# el `first` y el `.click`:
#
#     first(:button, …)                → MURIÓ
#     find(:button, …, match: :first)  → SOBREVIVIÓ
#
# `find(..., match: :first)` dice exactamente lo mismo y se recupera solo.
# `click_button "X", match: :first` es `find` + `click`, y hereda el rescate.
class NodosQueNoRecarganTest < ActiveSupport::TestCase
  # `first(algo).click`, con lo que sea adentro del paréntesis.
  ENCADENADO = /\bfirst\([^\n]*\)\.click\b/

  test "ningun system test aprieta un nodo de first(...)" do
    ofensores = []

    Dir.glob(Rails.root.join("test/system/**/*.rb")).sort.each do |archivo|
      File.readlines(archivo).each_with_index do |linea, i|
        # El comentario que explica la regla nombra el patrón a propósito.
        next if linea.lstrip.start_with?("#")
        next unless linea.match?(ENCADENADO)

        ruta = Pathname.new(archivo).relative_path_from(Rails.root)
        ofensores << "  #{ruta}:#{i + 1}  #{linea.strip}"
      end
    end

    assert_empty ofensores, <<~MSG
      Estos aprietan un nodo que Capybara **no sabe recargar**. Si la página se
      reemplaza entre el `first` y el `.click` —el preview de caché de Turbo lo
      hace todo el tiempo— revienta con `StaleElementReferenceError`, y encima
      solo en CI, que es donde la ventana es ancha.

      Cambialo por la forma que se recupera sola:

        first("button", text: "X").click   →  find("button", text: "X", match: :first).click
        first(:button, "X").click          →  click_button "X", match: :first

      #{ofensores.join("\n")}
    MSG
  end

  # El contrapeso: si el barrido deja de encontrar archivos, el test pasa vacío
  # y contento sin haber mirado nada.
  test "el barrido de verdad mira los system tests" do
    archivos = Dir.glob(Rails.root.join("test/system/**/*.rb"))

    assert_operator archivos.size, :>=, 40,
                    "el barrido dejó de enganchar los system tests"
  end
end
