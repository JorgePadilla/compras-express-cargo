require "application_system_test_case"

# C28-05 · El lápiz de una caja la trae al formulario de arriba, y F5 guarda
# los cambios en vez de agregar otra. Lo que importa acá es el navegador: que
# el formulario cambie a PATCH y que «Cancelar edición» lo devuelva a agregar.
class CajaEditarSystemTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami))
    @caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36)
  end

  test "editar la caja, corregir el peso y guardar con F5" do
    visit manifiesto_path(@manifiesto)

    find("button[aria-label='Editar la caja A']").click
    assert_text "Editando la caja A"
    assert_equal "23", find("#caja_manifiesto_alto").value.to_f.to_i.to_s
    assert_equal "caja_manifiesto_peso", page.evaluate_script("document.activeElement.id")

    find("#caja_manifiesto_peso").set("131")
    page.driver.browser.action.send_keys(:f5).perform

    assert_text "Caja A actualizada", wait: 5
    assert_equal 131, @caja.reload.peso.to_i
    assert_equal 1, @manifiesto.cajas.count, "no agregó otra"
  end

  test "cancelar la edición vuelve a agregar cajas" do
    visit manifiesto_path(@manifiesto)

    find("button[aria-label='Editar la caja A']").click
    click_button "Cancelar edición"
    assert_no_text "Editando la caja A"

    find("#caja_manifiesto_peso").set("5")
    page.driver.browser.action.send_keys(:f5).perform

    assert_text "Caja B agregada", wait: 5
    assert_equal 2, @manifiesto.cajas.count
  end
end
