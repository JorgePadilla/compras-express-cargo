require "application_system_test_case"

# PR-C6.33: el buscador del TERCERO se comporta como los demás.
#
# El tercero es quien retira el paquete cuando no es el titular. Busca en la
# misma tabla de clientes, así que el operario espera que se use igual — y
# hasta ahora no: era la única de las ocho copias que ya preseleccionaba y ya
# tenía flechas, pero seguía pidiendo **2 caracteres**, así que el código de un
# dígito no la abría.
#
# Este archivo existe porque la migración a `BusquedaAutocomplete` tocó esta
# pantalla y **nadie la había reportado rota**. Cambiar código que funciona sin
# dejarle una red es exactamente cómo se rompe lo que nadie estaba mirando.
class TerceroBusquedaTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5

    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5

    # El campo del tercero vive detrás de F4.
    page.send_keys(:f4)
    assert_selector "[data-tercero-search-target=input]", wait: 5
  end

  test "un solo digito abre la lista" do
    buscar("2")

    assert_selector "[data-index]", wait: 5
    assert_text "CEC-002"
  end

  test "el primero queda preseleccionado" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    assert all("[data-index]").first[:class].include?("bg-cec-teal/10")
  end

  test "Enter lo elige y llena el campo oculto" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-tercero-search-target=input]").send_keys(:enter)

    assert_equal clientes(:maria).id.to_s,
                 page.evaluate_script("document.querySelector('[data-tercero-search-target=terceroId]').value")
  end

  test "el boton de limpiar lo saca" do
    # El tercero es opcional: tiene que poder quitarse. Es lo único propio de
    # esta pantalla y no se puede perder en la unificación.
    buscar("2")
    assert_selector "[data-index]", wait: 5
    find("[data-tercero-search-target=input]").send_keys(:enter)

    find("[data-tercero-search-target=clearButton]").click

    assert_equal "", page.evaluate_script("document.querySelector('[data-tercero-search-target=terceroId]').value")
    assert_equal "", find("[data-tercero-search-target=input]").value
  end

  test "una sola letra NO abre la lista" do
    buscar("a")

    assert_no_selector "[data-index]", wait: 2
  end

  private

  def buscar(texto)
    campo = find("[data-tercero-search-target=input]")
    campo.click
    campo.send_keys(texto)
  end
end
