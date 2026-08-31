require "application_system_test_case"

# `PR-U6` · La pantalla de San Pedro, de punta a punta.
#
# Existe por un bug que la suite no podía ver: **la guía que se escribía en la
# fila que viene por defecto no se guardaba nunca**, y la pantalla contestaba
# «guardado.» igual. Jorge: *"siempre sale que faltan guías de proveedor aunque
# se ponga algo"*.
#
# La causa era `child_index: "nueva"`. `permit` solo reconoce una colección
# anidada cuando la llave matchea `/\A-?\d+\z/` —`Parameters.nested_attribute?`—,
# así que `guias_attributes` llegaba al modelo como `{}`. Ningún test de
# controller lo agarraba porque todos armaban los params a mano, con índices
# numéricos: el índice de texto solo existía en el HTML.
#
# Por eso estos son tests de sistema y no de controller: lo que estaba roto era
# **el nombre del campo**, y eso solo se ve mandando el formulario de verdad.
class GuiasAduanaTest < ApplicationSystemTestCase
  setup do
    @manifiesto = manifiestos(:enviado)
    ingresar(users(:admin))
  end

  test "la guía que se escribe en la fila de arranque se guarda" do
    visit edit_guias_aduana_path(@manifiesto)

    campo = all("input[name*='guias_attributes'][type='text']").first
    assert campo, "la pantalla tiene que abrir con una fila lista para escribir"
    campo.set("286441-1")
    click_on "Guardar"

    assert_text "guardado", wait: 5
    assert_equal ["286441-1"], @manifiesto.reload.guias.pluck(:numero)
  end

  test "se pueden agregar más guías y se guardan todas" do
    visit edit_guias_aduana_path(@manifiesto)

    all("input[name*='guias_attributes'][type='text']").first.set("286441-1")
    click_on "Agregar guía"
    all("input[name*='guias_attributes'][type='text']").last.set("286441-2")
    click_on "Guardar"

    assert_text "guardado", wait: 5
    assert_equal %w[286441-1 286441-2], @manifiesto.reload.guias.pluck(:numero).sort
  end

  test "quitar una guía ya guardada la borra de verdad" do
    @manifiesto.guias.create!(numero: "286441-1")
    @manifiesto.guias.create!(numero: "286441-2")

    visit edit_guias_aduana_path(@manifiesto)
    # `_destroy` + `hidden`, no `remove()`: si se borrara del DOM, Rails no se
    # enteraría de que hay que eliminarla y volvería al recargar.
    all("button[aria-label='Quitar esta guía']").first.click
    click_on "Guardar"

    assert_text "guardado", wait: 5
    assert_equal ["286441-2"], @manifiesto.reload.guias.pluck(:numero)
  end

  test "con la guía y la fecha puestas, deja de aparecer en lo que falta" do
    visit edit_guias_aduana_path(@manifiesto)
    all("input[name*='guias_attributes'][type='text']").first.set("286441-1")
    # El campo real queda `hidden` detrás del `altInput` de flatpickr, así que
    # se escribe por la instancia y no tecleando.
    page.execute_script(<<~JS)
      const i = document.querySelector("input[name='manifiesto[fecha_aduana]']")
      i._flatpickr ? i._flatpickr.setDate("2026-08-20", true) : (i.value = "2026-08-20")
    JS
    click_on "Guardar"

    assert_text "guardado", wait: 5
    @manifiesto.reload
    assert_equal ["286441-1"], @manifiesto.guias.pluck(:numero)
    assert @manifiesto.fecha_aduana.present?, "la fecha de aduana tampoco se guardó"
    refute Manifiesto.esperando_datos_de_san_pedro.exists?(@manifiesto.id),
           "con la guía y la fecha puestas ya no le falta nada"
  end

  test "el calendario que sale es el del proyecto, y en español" do
    visit edit_guias_aduana_path(@manifiesto)
    page.execute_script("document.querySelectorAll('input').forEach(i => i._flatpickr?.open())")

    assert_selector ".flatpickr-calendar.open", wait: 3
    dias = all(".flatpickr-weekday").map { |e| e.text.strip }.reject(&:empty?)
    assert_includes dias, "Mié", "el calendario no está en español: #{dias.inspect}"
  end
end
