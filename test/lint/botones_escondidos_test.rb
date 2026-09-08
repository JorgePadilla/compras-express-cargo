require "test_helper"

# Un `ButtonComponent` **no se esconde con la clase `hidden`**: se esconde con
# el atributo.
#
# Se encontró el 2026-09-08 mirando una captura de `/medicion`: el banner decía
# que el consolidado estaba completo y el botón «Facturar lo que hay» se veía
# igual. En el CSS compilado, `.inline-flex`, `.flex` y `.inline-block` vienen
# **después** de `.hidden`, así que en cualquier elemento que lleve una de esas
# —y `ButtonComponent` lleva `inline-flex`— la clase `hidden` pierde y el botón
# se ve. Con eso a la vista, en `/medicion` salían los tres botones del modal
# rojo a la vez, «Reimprimir» mientras se armaba la tanda, y el «×» de sacar de
# la lista lo veía el operario que no es admin; en `/empacar`, «Meterlo igual»
# siempre; en `/etiquetar`, «Todavía no» siempre.
#
# Y el test que lo cubría daba verde con el bug puesto, porque miraba la clase
# —`button:not(.hidden)`— y no si el botón se veía.
#
# El preflight de Tailwind trae `[hidden]{display:none!important}`, y ése no
# pierde con nadie. Así que la regla es una: en el ERB, `hidden: true`; en el
# JS, `el.hidden = …`. Este lint cubre la mitad del ERB; la del JS se cubre
# con el test de sistema que mira **visibilidad**, no clase.
class BotonesEscondidosTest < ActiveSupport::TestCase
  ERBS = Dir[Rails.root.join("app/views/**/*.erb")] + Dir[Rails.root.join("app/components/**/*.erb")]

  test "ningún ButtonComponent se esconde con la clase hidden" do
    culpables = ERBS.flat_map do |archivo|
      fuente = File.read(archivo)
      fuente.to_enum(:scan, /ButtonComponent\.new\((.*?)\)\)?\s*(?:do\b|\{|%>)/m).map do
        llamada = Regexp.last_match(1)
        next unless llamada.match?(/class:\s*["'][^"']*\bhidden\b/)

        linea = fuente[0, Regexp.last_match.begin(0)].count("\n") + 1
        "#{Pathname(archivo).relative_path_from(Rails.root)}:#{linea}"
      end.compact
    end

    assert_empty culpables, <<~MSG
      Estos ButtonComponent llevan la clase `hidden`, y esa clase **no los esconde**:
      `.inline-flex` viene después de `.hidden` en el CSS compilado. Usá `hidden: true`
      en el ERB y `el.hidden = …` en el JS.

      #{culpables.join("\n")}
    MSG
  end
end
