require "test_helper"

# Que ningún botón se quede sin hacer nada.
#
# Jorge, revisando el manifiesto: *"dale un scan que todos los botones tengan
# función y que sigan el standard"*.
#
# El barrido dio limpio —**109 `ButtonComponent` y 114 `<button>` crudos, todos
# con función**—, así que esto no arregla nada: **traba**. Que hoy no haya
# ninguno muerto es exactamente el momento de poner el trinquete, porque el
# número que hay que defender es cero.
#
# ── Por qué hacía falta uno nuevo ─────────────────────────────────────────
#
# El repo ya tenía tres guardias de botones, y ninguna mira esto:
#
#   · `botones_test` cuenta cuántos se escriben crudos — **consistencia**;
#   · `botones_accesibles_test` vigila nombre y foco — **accesibilidad**;
#   · `dashboard_controller_test` prohíbe `href="#"`, pero **solo en las
#     tarjetas del dashboard y en el sidebar**.
#
# Un botón puede ser consistente, accesible y aun así no hacer nada. Y fuera del
# dashboard, nadie lo miraba.
class BotonesConFuncionTest < ActiveSupport::TestCase
  # Qué cuenta como «tiene función»:
  #
  #   `href:`     va a algún lado
  #   `type:`     lo manda un formulario (`submit`)
  #   `action:`   lo escucha un controller de Stimulus
  #   `method:`   `button_to` con su verbo
  #   `form:`     está atado a un formulario por id
  CON_FUNCION = /href:|type:|action:|method:|form:/

  # Y en los crudos, sus equivalentes en HTML.
  CON_FUNCION_CRUDO = /
    type=["'](?:submit|reset)["'] | data-action | onclick |
    data-turbo | \bform= | data-shortcut | popovertarget | commandfor
  /x

  test "ningún ButtonComponent se queda sin función" do
    mudos = []

    cada_archivo do |ruta, cuerpo|
      cuerpo.scan(/ButtonComponent\.new\(([^\n]*(?:\n[^\n]*?)??)\)/m) do |(args)|
        next if args.match?(CON_FUNCION)

        linea = cuerpo[0...cuerpo.index(args)].count("\n") + 1
        mudos << "  #{ruta}:#{linea}  #{args.gsub(/\s+/, ' ')[0, 90]}"
      end
    end

    assert_empty mudos, <<~MSG
      Estos botones no llevan a ningún lado ni disparan nada. Para quien los
      aprieta, la pantalla no responde y no dice por qué.

      Poneles `href:`, `type: :submit`, un `data: { action: ... }` de Stimulus,
      o `method:` si son un `button_to`.

      #{mudos.join("\n")}
    MSG
  end

  test "ningún <button> crudo se queda sin función" do
    mudos = []

    cada_archivo do |ruta, cuerpo|
      cuerpo.scan(/<button\b[^>]*>/m) do |tag|
        next if tag.match?(CON_FUNCION_CRUDO)

        linea = cuerpo[0...cuerpo.index(tag)].count("\n") + 1
        mudos << "  #{ruta}:#{linea}  #{tag.gsub(/\s+/, ' ')[0, 90]}"
      end
    end

    assert_empty mudos, <<~MSG
      Estos `<button>` no hacen nada al apretarlos.

      Un `<button>` sin `type` adentro de un `<form>` **sí** manda el formulario
      —es el default de HTML—; si es ese el caso, ponele `type="submit"` para que
      se lea y para que este test lo reconozca.

      #{mudos.join("\n")}
    MSG
  end

  # El contrapeso. Sin esto, el día que los regex dejen de enganchar los dos
  # tests de arriba pasan vacíos y contentos sin haber mirado nada — que es
  # exactamente cómo se murió en silencio un test de `pre_alertas`.
  test "el barrido de verdad encuentra los botones" do
    componentes = 0
    crudos = 0

    cada_archivo do |_ruta, cuerpo|
      componentes += cuerpo.scan(/ButtonComponent\.new\(/).size
      crudos += cuerpo.scan(/<button\b/).size
    end

    assert_operator componentes, :>=, 100, "el regex del componente dejó de enganchar"
    assert_operator crudos, :>=, 100, "el regex del crudo dejó de enganchar"

    # Y que reconozca las dos formas: la que tiene función y la que no.
    assert_match CON_FUNCION, 'variant: :primary, href: manifiesto_path(m)'
    refute_match CON_FUNCION, 'variant: :primary, icon: "printer"'
    assert_match CON_FUNCION_CRUDO, '<button type="submit" class="x">'
    refute_match CON_FUNCION_CRUDO, '<button class="x">'
  end

  # ── «Volver» va a la izquierda, y por eso tiene slot propio ─────────────
  #
  # Jorge: *"las flechas para ir para atrás están raras y siempre a la derecha de
  # los botones; me parece que tiene más sentido siempre estar a lo más
  # izquierda"*.
  #
  # Estaban a la derecha por una razón tonta: `PageHeaderComponent` renderiza las
  # acciones **en orden de declaración**, y «Volver» se declaraba último porque es
  # lo último que uno escribe. La posición dependía del orden en que alguien
  # tipeó, no de una decisión.
  #
  # `with_back` la vuelve estructural: el slot se renderiza primero, siempre.
  # Esto traba que alguien vuelva a meterla entre las acciones.
  #
  # ── Ojo con las dos formas de cerrar el bloque ──────────────────────────
  #
  # Las vistas declaran acciones de dos maneras, y el lint tiene que ver las dos:
  #
  #     header.with_action do        …   end       ← Ruby, dentro de un `<%= … do |header| %>`
  #     <% h.with_action do %>       …   <% end %> ← ERB
  #
  # La primera versión de este lint cerraba sólo con `\n\s*end`, que nunca casa
  # con `<% end %>` porque el `<% ` se mete entre la sangría y el `end`. O sea
  # que las vistas en ERB —`empaque/show`, `recepcion_carga/show`— pasaban
  # verdes con el bug puesto. Se comprobó a mano: volviendo `empaque/show` a
  # `with_action`, el lint no decía nada.
  test "el botón de volver va en with_back, no entre las acciones" do
    fuera_de_lugar = []

    cada_archivo do |ruta, cuerpo|
      cuerpo.scan(/\w+\.with_action do\b.*?(?:\n\s*end\b|<%\s*end\s*%>)/m) do |bloque|
        next unless bloque.include?("arrow-left")

        linea = cuerpo[0...cuerpo.index(bloque)].count("\n") + 1
        fuera_de_lugar << "  #{ruta}:#{linea}"
      end
    end

    assert_empty fuera_de_lugar, <<~MSG
      Estos «Volver» están declarados como una acción más, así que caen a la
      derecha del grupo — y atrás es izquierda.

      Cambiá `with_action` por `with_back`: el slot se renderiza primero.

      #{fuera_de_lugar.join("\n")}
    MSG
  end

  private

  def cada_archivo
    Dir.glob(Rails.root.join("app/{views,components}/**/*.erb")).sort.each do |archivo|
      yield Pathname.new(archivo).relative_path_from(Rails.root).to_s, File.read(archivo)
    end
  end
end
