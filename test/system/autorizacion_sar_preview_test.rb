require "application_system_test_case"

# PR-F1.3 · Mientras se tipea el rango del CAI, se ven los dos números de 16
# dígitos que va a cubrir: es lo que se compara contra la resolución de la SAR.
class AutorizacionSarPreviewTest < ApplicationSystemTestCase
  test "el preview arma EEE-PPP-TT-NNNNNNNN con el punto, el tipo y el rango" do
    ingresar(users(:admin))
    visit new_autorizacion_sar_path

    select "001-001 · Humuya TGU", from: "Punto de emisión"
    select "07 · Nota de Débito", from: "Tipo de documento"
    fill_in "Rango: desde el número", with: "51"
    fill_in "Rango: hasta el número", with: "1050"

    assert_selector "[data-rango-sar-target='desde']", text: "001-001-07-00000051"
    assert_selector "[data-rango-sar-target='hasta']", text: "001-001-07-00001050"
    assert_selector "[data-rango-sar-target='cantidad']", text: /1[.,]000 documentos/
  end
end
