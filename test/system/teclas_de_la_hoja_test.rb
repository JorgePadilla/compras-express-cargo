require "application_system_test_case"

# C30-02 · Las teclas de la hoja de Yusef, en todo el sistema: F1 crear, F8
# guardar. La hoja (foto 2): *"F8 → Guardar · F9 → Guardar e Imprimir · F2 →
# Limpiar · F5 → Agregar · F4 → Imprimir · F1 → Crear"*.
#
# Lo que el lint (`teclas_por_familia_test`) no puede ver: que la tecla de
# verdad haga algo, y que F1 no deje pasar la Ayuda del navegador.
class TeclasDeLaHojaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
  end

  test "F1 abre el formulario de uno nuevo" do
    visit proveedores_path
    find("body").click
    page.driver.browser.action.send_keys(:f1).perform

    assert_current_path new_proveedor_path, wait: 5
  end

  test "F1 se frena siempre, aunque el foco esté en un campo y no haya botón «Nuevo»" do
    # En Windows, un F1 que nadie frena abre la Ayuda de Chrome. El Chrome de
    # los tests no la abre, así que lo que se afirma es que el `keydown` llegó
    # frenado (`defaultPrevented`). ⚠️ La prueba de verdad es a mano, en las
    # máquinas Windows del equipo (ver `keyboard_shortcuts_controller.js`).
    visit new_proveedor_path
    page.execute_script(<<~JS)
      window.__f1 = null
      window.addEventListener("keydown", (e) => { if (e.key === "F1") window.__f1 = e.defaultPrevented })
    JS
    find("#proveedor_nombre").click
    page.driver.browser.action.send_keys(:f1).perform

    hasta_que("el F1 no llegó a la página") { !page.evaluate_script("window.__f1").nil? }
    assert page.evaluate_script("window.__f1"), "F1 pasó sin frenar: en Windows abre la Ayuda de Chrome"
    assert_current_path new_proveedor_path
  end

  test "F8 guarda" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda F8")
    find("body").click
    page.driver.browser.action.send_keys(:f8).perform

    hasta_que("F8 no guardó") { Proveedor.exists?(nombre: "Tienda F8") }
  end

  # C30-02 · *«Lleno el último campo y aprieto F8»*: con el foco adentro del
  # campo, guarda — y una sola vez.
  test "F8 guarda con el foco adentro de un campo, una sola vez" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda F8 en campo")
    find("#proveedor_notas").click
    find("#proveedor_notas").send_keys("la última")
    page.driver.browser.action.send_keys(:f8).perform

    hasta_que("F8 no guardó desde el campo") { Proveedor.exists?(nombre: "Tienda F8 en campo") }
    assert_no_current_path new_proveedor_path, wait: 5
    assert_equal 1, Proveedor.where(nombre: "Tienda F8 en campo").count, "F8 guardó dos veces"
  end

  test "F10 y F7 ya no hacen nada" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda F10")
    find("body").click
    page.driver.browser.action.send_keys(:f10).perform
    page.driver.browser.action.send_keys(:f7).perform

    page.evaluate_script("new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))")
    assert_current_path new_proveedor_path
    assert_not Proveedor.exists?(nombre: "Tienda F10")
  end

  test "el portal del cliente también escucha las teclas" do
    # Mostraba «Nueva Pre-Alerta (F7)» y nadie la escuchaba: el atajo global
    # vivía solo en el layout de admin.
    Capybara.reset_sessions!
    visit new_session_path
    fill_in "email_address", with: clientes(:juan).codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"
    assert_current_path cuenta_root_path, wait: 5

    visit cuenta_pre_alertas_path
    find("body").click
    page.driver.browser.action.send_keys(:f1).perform

    assert_current_path new_cuenta_pre_alerta_path, wait: 5
  end

  # PR-C30.11 · F2 en la edición de una pre-alerta del portal: la pantalla la
  # escucha ella misma (`pre-alerta-editor`) y el «Volver (F2)» llevaba además
  # `data-shortcut`, así que el atajo global le hacía click también — dos
  # visitas por tecla. Turbo no recarga la ventana entre visitas, así que el
  # contador sobrevive y las cuenta.
  test "en el portal, F2 al editar una pre-alerta vuelve una sola vez" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "PA F2",
                           estado: "pre_alerta", creado_por_tipo: "cliente", creado_por_id: clientes(:juan).id)
    pa.pre_alerta_paquetes.create!(tracking: "TRKF2#{SecureRandom.hex(3)}", descripcion: "Ropa", fecha: Date.current)
    entrar_al_portal

    visit edit_cuenta_pre_alerta_path(pa)
    assert_text "Volver (F2)"
    page.execute_script("window.__visitas = 0; document.addEventListener('turbo:visit', () => window.__visitas++)")
    find("body").click
    page.driver.browser.action.send_keys(:f2).perform

    assert_current_path cuenta_pre_alertas_path, wait: 5
    assert_equal 1, page.evaluate_script("window.__visitas"), "F2 visitó dos veces"
  end

  # PR-C30.11 · Con un modal hecho con `div` abierto —el «Confirmar»
  # compartido—, F8 no aprieta el «Guardar» de atrás. Antes la guarda miraba
  # solo `<dialog open>`.
  test "con el modal de confirmar abierto, F8 no guarda lo de atrás" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda detrás del modal")
    page.execute_script("window.cecConfirm('¿Seguro?')")
    assert_selector "[data-confirm-modal-target='root'][aria-modal='true']", visible: true

    page.driver.browser.action.send_keys(:f8).perform

    page.evaluate_script("new Promise(r => setTimeout(r, 300))")
    assert_current_path new_proveedor_path
    assert_not Proveedor.exists?(nombre: "Tienda detrás del modal"), "F8 guardó con el modal abierto"
    assert_selector "[data-confirm-modal-target='root']", visible: true
  end

  test "con el modal de confirmar abierto, F1 no abre «Nuevo» detrás" do
    visit proveedores_path
    page.execute_script("window.cecConfirm('¿Seguro?')")
    assert_selector "[data-confirm-modal-target='root']", visible: true

    page.driver.browser.action.send_keys(:f1).perform

    page.evaluate_script("new Promise(r => setTimeout(r, 300))")
    assert_current_path proveedores_path
  end

  # Y cerrado el modal, las teclas vuelven: la guarda mira si se **ve**, no si
  # el modal existe (está en todas las páginas, escondido).
  test "con el modal de confirmar cerrado, F8 guarda como siempre" do
    visit new_proveedor_path
    find("#proveedor_nombre").set("Tienda modal cerrado")
    assert_selector "[data-confirm-modal-target='root']", visible: :hidden
    find("body").click
    page.driver.browser.action.send_keys(:f8).perform

    hasta_que("F8 no guardó con el modal cerrado") { Proveedor.exists?(nombre: "Tienda modal cerrado") }
  end

  private

  def entrar_al_portal
    Capybara.reset_sessions!
    visit new_session_path
    fill_in "email_address", with: clientes(:juan).codigo
    fill_in "password", with: "Cliente123!"
    click_on "Iniciar Sesion"
    assert_current_path cuenta_root_path, wait: 5
  end

  # Lo que no es un nodo, con la paciencia de Capybara (el bucle `synchronize`
  # de sus matchers), sin `sleep`.
  def hasta_que(mensaje, wait: Capybara.default_max_wait_time)
    page.document.synchronize(wait, errors: [ Capybara::ExpectationNotMet ]) do
      raise Capybara::ExpectationNotMet, mensaje unless yield
    end
    assert true
  rescue Capybara::ExpectationNotMet
    flunk mensaje
  end
end
