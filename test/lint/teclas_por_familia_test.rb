require "test_helper"

# C23-13 · Una tecla no puede significar dos cosas distintas.
#
# Jorge, mirando la app: *"¿los F los podemos dejar iguales en las pantallas?"*
#
# El mapa completo salió casi limpio —F2 volver, F6 editar, F7 nuevo, F10
# guardar, con decenas de usos cada una— y con **una sola** tecla mezclada:
# `F8` era «Excel» en toda la app y «Finalizar e Imprimir» en el manifiesto,
# porque la puse ahí cuatro días antes en `C23-12`. Se movió a `F11`, que ya
# quiere decir finalizar (la «Finalizar sesión» de `/etiquetar`, que eligió
# Yusef).
#
# Este lint es para que no vuelva a pasar: es barato agregar un botón con la
# tecla libre que uno ve en la pantalla que está tocando, sin saber que esa
# tecla ya significa algo en las otras veinte.
#
# **Compara familias, no rótulos.** «Nueva Pre-Alerta» y «Nuevo Proveedor» son
# la misma tecla y está bien; lo que no puede es que F8 sea «Excel» acá y
# «Finalizar» allá.
class TeclasPorFamiliaTest < ActiveSupport::TestCase
  # Qué quiere decir cada tecla, en palabras que aparecen en el rótulo del
  # botón. Sale de leer lo que la app **hace**, no de una convención escrita:
  # ver el encabezado de `keyboard_shortcuts_controller.js`.
  FAMILIAS = {
    "F2"  => /volver|cancelar|limpiar|atr[áa]s/i,
    "F3"  => /.*/,                                   # solo /etiquetar, con su propio handler
    "F4"  => /imprimir|warehouse|recibo|documento/i,
    "F5"  => /agregar|a[ñn]adir/i,
    "F6"  => /editar|modificar/i,
    "F7"  => /nuev[oa]|crear/i,
    "F8"  => /excel|exportar/i,
    "F9"  => /imprimir|pdf/i,
    "F10" => /guardar|finalizar|confirmar|aplicar/i,
    "F11" => /finalizar|cerrar/i
  }.freeze

  test "ninguna tecla significa dos cosas distintas" do
    fuera = []

    cada_boton_con_tecla do |ruta, tecla, etiqueta|
      familia = FAMILIAS[tecla]
      next fuera << "  #{ruta}  #{tecla} no está en la convención — #{etiqueta}" if familia.nil?
      next if etiqueta.match?(familia)

      fuera << "  #{ruta}  #{tecla} = «#{etiqueta}», y #{tecla} quiere decir #{familia.source.tr('|', '/')}"
    end

    assert_empty fuera, <<~MSG
      Teclas que no dicen lo mismo que en el resto de la app:

      #{fuera.join("\n")}

      Una tecla se aprende una vez y se usa en todas las pantallas. Si esta
      acción de verdad es otra familia, elegí la tecla que ya la significa
      (ver `keyboard_shortcuts_controller.js`); si de verdad hace falta una
      familia nueva, agregala a FAMILIAS con el porqué.
    MSG
  end

  # La tecla escrita **a mano** adentro del texto del botón cuenta igual.
  #
  # Es como se escondían las tres de `/pre_alertas/edit`: decían «Agregar
  # Paquete (F6)» y «Guardar (F8)» con el «(F6)» dentro del bloque, sin
  # `shortcut:`, así que el lint no las veía — y eran justo las que
  # contradecían al resto de la app. Se leen igual de bien que las de verdad,
  # así que valen igual.
  #
  # Lo correcto cuando la tecla la escucha el controller de la pantalla es
  # `shortcut_label_only`, que pinta el rótulo sin emitir `data-shortcut`.
  test "la tecla escrita a mano en el texto también cuenta" do
    a_mano = []

    cada_boton do |ruta, args, etiqueta|
      escrita = etiqueta[/\((F\d+)\)/, 1]
      next if escrita.nil? || args.match?(/shortcut:/)

      a_mano << "  #{ruta}  «#{etiqueta}»"
    end

    assert_empty a_mano, <<~MSG
      Botones con la tecla escrita adentro del texto:

      #{a_mano.join("\n")}

      Pasala a `shortcut:` para que el rótulo lo pinte el componente y este
      lint la pueda ver. Si la escucha el controller de la pantalla, va con
      `shortcut_label_only: true` para no dispararla dos veces.
    MSG
  end

  private

  def corta(ruta)
    ruta.to_s.sub(%r{.*/app/views/}, "").sub(".html.erb", "")
  end

  def cada_boton
    Dir.glob(Rails.root.join("app/views/**/*.erb")).sort.each do |ruta|
      cuerpo = File.read(ruta)
      cada_llamada(cuerpo) { |args, etiqueta, _| yield corta(ruta), args, etiqueta }
    end
  end

  # La tecla vale venga de `shortcut:` **o** escrita a mano en el texto: las dos
  # se leen igual en la pantalla, así que las dos prometen lo mismo.
  def cada_boton_con_tecla
    cada_boton do |ruta, args, etiqueta|
      tecla = args[/shortcut:\s*"(F\d+)"/, 1] || etiqueta[/\((F\d+)\)/, 1]
      next if tecla.nil? || etiqueta.empty?

      yield ruta, tecla, etiqueta
    end
  end

  # Recorre las llamadas a `ButtonComponent.new(...)` **cerrando el paréntesis
  # de verdad**, y de ahí toma su etiqueta.
  #
  # Con un regex perezoso la primera versión de esto cruzaba de un botón al
  # siguiente y reportaba que `guias_aduana/edit` tenía «Agregar guía» en F2 —
  # un hallazgo entero que no existía: la F2 era del «Volver» cien líneas
  # arriba. Por eso se cuentan paréntesis en vez de confiar en `.*?`.
  def cada_llamada(cuerpo)
    cuerpo.to_enum(:scan, /ButtonComponent\.new\(/).each do
      ini = Regexp.last_match.begin(0)
      i = ini + "ButtonComponent.new(".length
      profundidad = 1
      while i < cuerpo.length && profundidad.positive?
        profundidad += 1 if cuerpo[i] == "("
        profundidad -= 1 if cuerpo[i] == ")"
        i += 1
      end
      args = cuerpo[ini...i]
      cola = cuerpo[i, 200].to_s
      etiqueta = cola[/\A\s*do\s*%>(.*?)<%\s*end/m, 1] ||
                 cola[/\A\s*\{\s*"([^"]*)"/, 1] ||
                 args[/label:\s*"([^"]+)"/, 1]
      yield args, limpia(etiqueta), i
    end
  end

  def limpia(texto)
    texto.to_s.gsub(/<%.*?%>/m, " ").gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
  end
end
