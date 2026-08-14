require "test_helper"

# `x = valor unless defined?(x)` **nunca asigna**. Este lint lo prohíbe.
#
# No es una sutileza de Rails: es Ruby. El parser define la variable local al
# *leer* la asignación, antes de evaluar la condición, así que `defined?(x)` ya
# es truthy cuando se pregunta:
#
#     def f
#       y = :default unless defined?(y)
#       y            # => nil
#     end
#
# Lo que costó: `shared/_peso_medidas_calc` resolvía así su `modo_cajas`. Con el
# default sin aplicar, `/etiquetar` perdió el campo de cajas —y con él la única
# forma de dividir un paquete— el mismo día que `PR-C7.04` forkeó ese bloque.
# Nadie lo vio hasta que Jorge lo reportó dos días después: *"veo que en etiqueta
# no me deja agregar más cajas como en entrega personal, ¿qué pasó?"*.
#
# El daño fue silencioso en las dos puntas: la vista rendía sin error y el
# controller leía un campo ausente como "cero cajas".
#
# La forma que sí funciona sobre el nil que deja Rails es `||=`, o
# `local_assigns.fetch(:x, default)` cuando el default puede ser falsy. Y para un
# bloque con varios locales, un ViewComponent con kwargs — que es adonde se mudó
# este.
class DefaultsDePartialTest < ActiveSupport::TestCase
  PATRON = /unless\s+defined\?\(/
  # Los comentarios de ERB no ejecutan nada, y este bug se explica en varios —
  # citarlo no puede hacer fallar el lint que lo prohíbe.
  COMENTARIO_ERB = /<%#.*?%>/m

  test "ninguna vista ni componente resuelve defaults con unless defined?" do
    culpables = Dir.glob(Rails.root.join("app/{views,components}/**/*.erb")).filter_map do |ruta|
      src = File.read(ruta).gsub(COMENTARIO_ERB, "")
      next unless src.match?(PATRON)

      linea = src.lines.index { |l| l.match?(PATRON) }.to_i + 1
      "#{ruta.sub("#{Rails.root}/", "")} (línea ~#{linea}, sin contar comentarios)"
    end

    assert_empty culpables, <<~MSG
      `x = valor unless defined?(x)` no asigna nunca — el parser de Ruby ya
      definió `x` cuando evalúa el `defined?`, así que el default se pierde y la
      variable queda en nil, en silencio.

      Usá `x ||= valor`, o `local_assigns.fetch(:x, valor)` si el default puede
      ser falsy. Si el bloque tiene varios locales, hacelo un ViewComponent.

      #{culpables.join("\n")}
    MSG
  end
end
