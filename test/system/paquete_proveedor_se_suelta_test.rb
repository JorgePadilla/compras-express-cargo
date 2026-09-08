require "application_system_test_case"

# C27-29 · Teclear encima del proveedor tiene que soltar el del catálogo.
#
# Jorge, 2026-09-07, editando un paquete en vivo: *"está en F10… no lo está
# cambiando… el guardar"* — y enseguida **"ya, ya, ya, es que este es el
# proveedor"**.
#
# Eran dos bugs uno encima del otro. El de abajo: el input visible no tenía
# `name`, así que lo tecleado no salía del navegador. El de arriba, que solo
# aparece al arreglar el primero: `proveedor_id` se escribía al elegir del
# dropdown y **no se limpiaba nunca**, así que el formulario mandaba las dos
# cosas —el id viejo y el texto nuevo— y la ficha seguía diciendo "Amazon".
#
# Va como system test porque el bug vive entre el JS y el DOM: en un test de
# controller los params se arman a mano y el hidden nunca sobreviviría solo.
# Es el mismo caso de `etiquetar_tercero_se_limpia_test`.
class PaqueteProveedorSeSueltaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
    @paquete = paquetes(:recibido)
    visit paquete_path(@paquete, mode: "edit")
    assert_selector "#paquete-edit-form", wait: 5
  end

  def proveedor_id
    page.evaluate_script("document.querySelector(\"input[name='paquete[proveedor_id]']\").value")
  end

  def campo_visible
    find("[data-proveedor-autocomplete-target=input]")
  end

  test "el campo visible manda lo que se teclea" do
    assert_equal "paquete[proveedor_texto]", campo_visible[:name],
                 "sin `name` el navegador no manda nada y el proveedor se pierde en silencio"
  end

  test "teclear encima suelta el proveedor del catálogo" do
    assert_equal proveedores(:Amazon).id.to_s, proveedor_id,
                 "el fixture tiene que llegar con uno del catálogo elegido"

    campo_visible.fill_in with: "Driver Juan"

    assert_equal "", proveedor_id,
                 "el id viejo sobrevivió: al guardar gana el del catálogo y la ficha " \
                 "sigue diciendo Amazon — el «no lo está cambiando» de Jorge"
  end

  test "elegir del dropdown vuelve a poner el id" do
    campo_visible.fill_in with: "Wal"

    assert_selector "[data-proveedor-autocomplete-target=dropdown] [data-index]", wait: 5
    find("[data-proveedor-autocomplete-target=dropdown] [data-index]", match: :first).click

    assert_equal proveedores(:Walmart).id.to_s, proveedor_id,
                 "soltar lo elegido al teclear no puede romper el elegir"
  end
end
