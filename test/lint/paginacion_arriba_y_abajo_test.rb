require "test_helper"

# PR-PAG.1 · La paginación, arriba y abajo, igual en todas las pantallas.
# Jorge, 2026-10-15: *"make sure the pagination is visible in the bottom and
# top, try to make pagination all the same in all views"*.
#
# Las 28 listas ya usaban `PaginationComponent`, pero solo abajo, y cada una
# lo envolvía a su manera (`mt-4`, `mt-6`, nada). Esto vigila las dos cosas:
#
#   · toda vista que pagina lo dibuja **dos veces**, una con `posicion: :arriba`
#     y otra abajo (sin posición, o `:abajo`), y de la misma colección;
#   · ninguna le pone margen alrededor: el margen lo pone el componente, según
#     dónde va. Un `px-*` sí se deja, porque es el borde de la tarjeta, no el
#     espacio entre la tabla y el paginador.
#
# Se probó rompiéndolo: quitar el de arriba de `ventas/index` y envolver el de
# abajo de `recibos/index` en `<div class="mt-4">` hace fallar a los dos tests.
class PaginacionArribaYAbajoTest < ActiveSupport::TestCase
  RENDER = /render\s+PaginationComponent\.new\((?<args>[^)]*)\)/

  def vistas
    Dir.glob(Rails.root.join("app/views/**/*.erb")).select { |f| File.read(f).include?("PaginationComponent.new") }
  end

  def relativo(f) = Pathname(f).relative_path_from(Rails.root).to_s

  test "hay vistas que paginan (si no, este lint no mira nada)" do
    assert_operator vistas.size, :>=, 20
  end

  test "toda vista que pagina lo dibuja arriba y abajo, de la misma colección" do
    malas = vistas.filter_map do |f|
      usos = File.read(f).scan(RENDER).flatten
      arriba = usos.select { |a| a.include?("posicion: :arriba") }
      abajo = usos - arriba
      coleccion = ->(a) { a[/collection:\s*(@\w+)/, 1] }
      next if arriba.size == 1 && abajo.size == 1 && coleccion.(arriba.first) == coleccion.(abajo.first)

      "  #{relativo(f)}: #{arriba.size} arriba, #{abajo.size} abajo"
    end

    assert_empty malas, <<~MSG
      Estas vistas no dibujan la paginación arriba y abajo:

      #{malas.join("\n")}

      Encima de la tabla: render PaginationComponent.new(collection: @x, label: "x", posicion: :arriba)
      Debajo: el mismo, sin posición.
    MSG
  end

  test "ninguna vista le pone margen al paginador: lo pone el componente" do
    envueltos = vistas.flat_map do |f|
      File.read(f).scan(/<div class="[^"]*\bm[tby]?-\d+[^"]*">\s*<%=\s*render\s+PaginationComponent/m).map { relativo(f) }
    end

    assert_empty envueltos, <<~MSG
      Paginadores envueltos en un div con margen. El componente ya pone el
      suyo (mb-3 arriba, mt-4 abajo); con otro encima, cada pantalla queda
      distinta otra vez:

      #{envueltos.uniq.join("\n")}
    MSG
  end
end
