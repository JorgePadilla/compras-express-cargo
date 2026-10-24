require "application_system_test_case"

# C32-01 · El historial de manifiestos después de «Buscar». Jorge,
# 2026-10-24: *"ocultar o minimizar los filtros una vez que presionamos
# buscar y mover el focus a los resultados"*. Los filtros ocupaban toda la
# primera pantalla, y al volver de la búsqueda la lista quedaba abajo y el
# foco arrancaba de nuevo arriba.
class HistorialPliegaLosFiltrosTest < ApplicationSystemTestCase
  FILTROS = "details[data-filtros='historial']".freeze

  setup do
    ingresar(users(:digitador))
    visit historial_manifiestos_path
  end

  test "al entrar están abiertos y el foco no baja" do
    assert_selector "#{FILTROS}[open]"
    assert_field "Buscar", visible: true
    assert_not_equal "resultados", foco
  end

  test "Buscar los pliega, dice qué quedó aplicado y el foco cae en los resultados" do
    find("label", text: "Creado", exact_text: true).click
    click_button "Buscar"

    assert_selector "#{FILTROS}:not([open])"
    assert_no_field "Buscar", visible: true
    assert_selector "#{FILTROS} summary", text: "Enviado, En aduana, Recibido, #{Manifiesto::TERMINADO_DE_PREFACTURAR}"
    assert_eventualmente("el foco no bajó a los resultados") { foco == "resultados" }
  end

  test "Enter en el buscador hace lo mismo que el botón" do
    fill_in "Buscar", with: manifiestos(:creado).numero
    find_field("Buscar").send_keys(:enter)

    assert_selector "#{FILTROS}:not([open])"
    assert_eventualmente("el foco no bajó a los resultados") { foco == "resultados" }
    assert_selector "h2#resultados", text: "Resultados · 1 manifiesto"
  end

  test "se vuelven a abrir con el teclado, con lo que se buscó puesto" do
    fill_in "Buscar", with: manifiestos(:creado).numero
    click_button "Buscar"
    assert_eventualmente("el foco no bajó a los resultados") { foco == "resultados" }

    page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
    page.driver.browser.action.send_keys(:enter).perform

    assert_selector "#{FILTROS}[open]"
    assert_field "Buscar", with: manifiestos(:creado).numero, visible: true
  end

  test "la página 2 sigue plegada y con el foco en los resultados" do
    11.times { Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ]) }
    visit historial_manifiestos_path(buscado: "1", per: 10)
    assert_eventualmente("el foco no bajó a los resultados") { foco == "resultados" }

    within("[data-paginacion='arriba']") { click_link "2" }

    assert_current_path(/page=2/)
    assert_selector "#{FILTROS}:not([open])"
    assert_eventualmente("el foco no bajó a los resultados") { foco == "resultados" }
  end

  test "Limpiar filtros los vuelve a abrir" do
    click_button "Buscar"
    assert_selector "#{FILTROS}:not([open])"

    find("#{FILTROS} summary").click
    click_link "Limpiar filtros"

    assert_selector "#{FILTROS}[open]"
    assert_not_equal "resultados", foco
  end

  private

  def foco = page.evaluate_script("document.activeElement?.id")
end
