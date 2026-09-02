require "application_system_test_case"

# El tercero sobrevivía a limpiar el formulario, y eso **guardaba datos mal en
# silencio**.
#
# `paquete[tercero_id]` es un `hidden`, y `_limpiarCampos` excluye los hidden a
# propósito —ahí viven el token CSRF y el `_method` de Rails—. `clearForm` solo
# escondía el bloque del tercero. Resultado: F2 vaciaba el campo **que se ve** y
# dejaba el id puesto, así que el paquete siguiente se guardaba con el tercero
# del anterior y **nada lo mostraba en pantalla**.
#
# `toggleTercero` (F4) sí lo limpiaba desde siempre. Los dos caminos hacían
# distinto lo mismo — la forma exacta en que este archivo se lastima.
#
# Va como system test porque el bug vive entre el JS y el DOM: en un test de
# controller los params se arman a mano y el hidden nunca sobreviviría solo.
class EtiquetarTerceroSeLimpiaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end

  def tercero_id = page.evaluate_script("document.querySelector(\"input[name*='tercero_id']\").value")

  def elegir_un_tercero
    find("body").send_keys(:f4)
    assert_selector "[data-tercero-search-target=input]", visible: true, wait: 5

    find("[data-tercero-search-target=input]").send_keys("CEC-002")
    assert_selector "[data-tercero-search-target=dropdown] [data-index]", wait: 5
    find("[data-tercero-search-target=dropdown] [data-index]", match: :first).click

    assert_equal clientes(:maria).id.to_s, tercero_id, "no quedó elegido el tercero"
  end

  test "F2 se lleva el tercero, no solo el campo que se ve" do
    elegir_un_tercero

    find("body").send_keys(:f2)

    assert_equal "", tercero_id,
                 "el id del tercero sobrevivió: el paquete siguiente se guardaría con él"
  end

  test "el botón Limpiar hace lo mismo que F2" do
    elegir_un_tercero

    # Hay dos: la barra de atajos va arriba y abajo, que lo pidió Yusef —*"estos
    # botones los dejaste abajo y a veces se ocupan acá arriba"*.
    find("button", text: "Limpiar", match: :first).click

    assert_equal "", tercero_id
  end

  # El camino que sí funcionaba, para que no se rompa al unificarlos: esconder
  # el bloque con F4 limpia la selección, *"para no mandar un tercero que el
  # operario ya no ve"*.
  test "F4 escondiendo el bloque sigue limpiando el tercero" do
    elegir_un_tercero

    find("body").send_keys(:f4)

    assert_equal "", tercero_id
  end
end
