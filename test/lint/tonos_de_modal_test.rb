require "test_helper"
require "botones_crudos"

# PR-C29.12 · Un tono por intención, en todos los modales de la app.
#
# Jorge, 2026-10-08, mirando «Su consolidado ya se midió» en medición: *"the
# orange in here feels different from the other; I would like to somehow have
# a standard on the colors use"*. El naranja era `amber-700` sólido, y no había
# regla: cada modal pintaba su franja a mano — rojo, navy, ámbar, gris, teal
# claro, o ninguna.
#
# La regla vive en `ModalHeaderComponent::TONOS` y en la tabla de
# `docs/07_design_system.md`. Este archivo hace que no se pueda volver atrás:
#
#   1. amber nunca va sólido: solo el claro de las notas;
#   2. todo modal pinta su franja con `ModalHeaderComponent`, no a mano;
#   3. los tonos son los cinco, ni uno más;
#   4. el aviso de /etiquetar, que cambia de tono en vivo, lee las clases del
#      servidor y no tiene una copia propia en el JS.
class TonosDeModalTest < ActiveSupport::TestCase
  RUTAS = BotonesCrudos::RUTAS.flat_map { |patron| Dir.glob(Rails.root.join(patron)) }.uniq.freeze
  RUBY = Dir.glob(Rails.root.join("app/components/**/*.rb")).freeze

  # Los `fixed inset-0` que **no** son modales: el fondo del sidebar en el
  # celular, en los dos layouts. Cada excepción dice cuántos tiene y por qué.
  NO_SON_MODALES = {
    "app/views/layouts/application.html.erb" => 1, # fondo del sidebar abierto en el celular
    "app/views/layouts/cuenta.html.erb" => 1       # ídem, en el portal del cliente
  }.freeze

  # Un ámbar sólido: `bg-amber-500` a `-900` sin opacidad. El par oscuro de las
  # notas (`dark:bg-amber-900/20`) no cuenta: es claro sobre oscuro.
  AMBAR_SOLIDO = %r{(?<![\w-])((?:[\w-]+:)*)bg-amber-[5-9]00(?![\w/])}

  test "amber nunca va sólido: es el claro de las notas" do
    culpables = []

    (RUTAS + RUBY).each do |archivo|
      fuente = BotonesCrudos.sin_comentarios(File.read(archivo))
      fuente.each_line.with_index(1) do |linea, n|
        next if linea.lstrip.start_with?("#")

        linea.scan(AMBAR_SOLIDO) do |(prefijos)|
          next if prefijos.to_s.include?("dark:")

          culpables << "#{relativa(archivo)}:#{n}  #{linea.strip[0, 100]}"
        end
      end
    end

    assert_empty culpables, <<~MSG
      Ámbar sólido. En la paleta, amber es para notas y en claro (`bg-amber-50`);
      un aviso usa la franja de `ModalHeaderComponent` y un botón, otro variant
      (ver docs/07, «Modales — un tono por intención»):
      #{culpables.join("\n")}
    MSG
  end

  test "todo modal pinta su franja con ModalHeaderComponent" do
    culpables = []

    RUTAS.each do |archivo|
      fuente = BotonesCrudos.sin_comentarios(File.read(archivo))
      modales = fuente.scan(/<dialog\b/).size +
                fuente.scan(/class="[^"]*\bfixed inset-0\b/).size -
                NO_SON_MODALES.fetch(relativa(archivo), 0)
      franjas = fuente.scan(/ModalHeaderComponent\.new/).size
      next if modales <= franjas

      culpables << "#{relativa(archivo)}: #{modales} modal(es), #{franjas} franja(s) con el componente"
    end

    assert_empty culpables, <<~MSG
      Modales con la franja escrita a mano. Va `render ModalHeaderComponent.new(tono: …)`
      con el tono de lo que el modal le pide al operario (bloqueo, atencion, info,
      listo o notas). Si algo de verdad no es un modal, va a NO_SON_MODALES con su porqué:
      #{culpables.join("\n")}
    MSG
  end

  test "los tonos son los cinco" do
    assert_equal %i[bloqueo atencion info listo notas], ModalHeaderComponent::TONOS.keys
  end

  test "ningún tono es ámbar sólido ni sale de la paleta" do
    ModalHeaderComponent::TONOS.each do |tono, clases|
      assert_no_match AMBAR_SOLIDO, clases.gsub(/\S*dark:\S+/, ""), "el tono #{tono} es ámbar sólido"
      assert_match(/\bbg-(red-700|cec-gold|cec-navy|cec-teal|amber-50)\b/, clases, "el tono #{tono} no sale de la paleta")
    end
  end

  # El aviso de /etiquetar cambia de tono según de qué avisa (retención, tarea,
  # nota). Antes el JS tenía su propia tabla de clases, que ya no coincidía con
  # nada: la retención era `red-600` y la nota, navy.
  test "el aviso de /etiquetar lee los tonos del servidor" do
    js = File.read(Rails.root.join("app/javascript/controllers/etiquetar_controller.js"))
    vista = File.read(Rails.root.join("app/views/etiquetar/index.html.erb"))

    assert_no_match(/TONOS_DE_AVISO/, js, "el JS volvió a tener su propia tabla de tonos")
    assert_match(/tonosValue/, js)
    assert_match(/data-etiquetar-tonos-value=.*ModalHeaderComponent\.clases\(:bloqueo\)/, vista)
  end

  private

  def relativa(archivo) = archivo.to_s.delete_prefix("#{Rails.root}/")
end
