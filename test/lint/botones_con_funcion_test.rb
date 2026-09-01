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

  private

  def cada_archivo
    Dir.glob(Rails.root.join("app/{views,components}/**/*.erb")).sort.each do |archivo|
      yield Pathname.new(archivo).relative_path_from(Rails.root).to_s, File.read(archivo)
    end
  end
end
