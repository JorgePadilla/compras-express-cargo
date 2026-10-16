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

  # C29-06 · «Guardar e imprimir» reventaba en staging y acá daba verde: el
  # ambiente de test apaga la protección CSRF, que es justo lo que fallaba.
  # Estos dos la prenden desde que se dibuja la página: sin protección,
  # `csrf_meta_tags` ni siquiera escribe el `<meta>`.
  def con_csrf
    antes = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = antes
  end

  test "editar la caja y guardar e imprimir con F9" do
    con_csrf do
      visit manifiesto_path(@manifiesto)

      find("button[aria-label='Editar la caja A']").click
      find("#caja_manifiesto_peso").set("41")
      page.driver.browser.action.send_keys(:f9).perform

      assert_current_path(/etiqueta/, wait: 5)
    end
    assert_equal 41, @caja.reload.peso.to_i
    assert_equal 1, @manifiesto.cajas.count, "no agregó otra"
  end

  test "editar la caja y guardar e imprimir con el botón" do
    con_csrf do
      visit manifiesto_path(@manifiesto)

      find("button[aria-label='Editar la caja A']").click
      find("#caja_manifiesto_peso").set("41")
      click_button "Guardar e imprimir"

      assert_current_path(/etiqueta/, wait: 5)
    end
    assert_equal 41, @caja.reload.peso.to_i
    assert_equal 1, @manifiesto.cajas.count, "no agregó otra"
  end
  # C32-07 · Yusef editó una caja, guardó, imprimió, y salió la etiqueta de la
  # otra: *"esta era la que yo tenía marcada en ese momento"*. «Guardar e
  # imprimir» imprime la editada aunque la Abierta sea otra; y con «Guardar
  # cambios» la fila editada queda marcada, distinta de la Abierta.
  test "con dos cajas, guardar e imprimir la que no está abierta imprime esa, y guardar la marca" do
    otra = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10)
    con_csrf do
      visit manifiesto_path(@manifiesto)
      page.execute_script("window.open = function(){}")
      find("button[aria-label='Editar la caja B']").click
      find("#caja_manifiesto_peso").set("125")
      click_button "Guardar e imprimir"

      assert_current_path(%r{/cajas/#{otra.id}/etiqueta}, wait: 5)
    end
    assert_equal 125, otra.reload.peso.to_i

    visit manifiesto_path(@manifiesto)
    find("button[aria-label='Editar la caja A']").click
    find("#caja_manifiesto_peso").set("7")
    page.driver.browser.action.send_keys(:f5).perform

    assert_text "Caja A actualizada", wait: 5
    assert_selector "tr[data-caja='A'][data-caja-editada]", text: "Recién editada"
    assert_no_selector "tr[data-caja='B'][data-caja-editada]"
  end
end
