require "application_system_test_case"

# C30-03 · Yusef, 2026-10-09: *"la descripción me la está dejando dejar vacía …
# ok, descripción tiene que estar llena"*.
#
# Lo que el test de integración no ve: el aviso en pantalla. La descripción
# lleva `required` como el tracking, así que el navegador la marca igual — y
# F9 la revisa **antes** de abrir el «¿cuántas etiquetas?»: si no, el operario
# contestaba el modal y recién ahí le salía el aviso, debajo de lo que acababa
# de cerrar.
class EtiquetarDescripcionObligatoriaSystemTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
  end

  test "F9 sin descripción no abre el modal, no graba, y deja el foco en la descripción" do
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    tracking = "1ZC3003SISTEMA1"
    find("#paquete_tracking").set(tracking)
    elegir_juan("etiquetar")

    tecla(:f9)

    assert_no_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 1
    assert_equal "paquete_descripcion", foco_actual
    assert_equal 0, Paquete.where(tracking: tracking).count
    # Jorge, 2026-10-10: el globo salía en inglés, con el texto de Chrome.
    assert_equal "Escribí qué viene en el paquete.", mensaje_de("#paquete_descripcion")
  end

  test "los avisos del navegador salen en español en cualquier campo obligatorio" do
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)

    tecla(:f9)

    assert_equal "Completá este campo.", mensaje_de("#paquete_tracking")
  end

  test "un campo que la pantalla llena por JS no se queda trabado con el aviso" do
    # `setCustomValidity` deja inválido al campo **aunque se llene**. Al que no
    # muestra el globo lo puede llenar la pantalla sin un `input` (el cliente
    # que sale de la pre-alerta al escanear): el F9 siguiente no puede frenar.
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    page.execute_script(<<~JS)
      const f = document.createElement("form")
      f.id = "prueba-avisos"
      f.innerHTML = '<input id="primero" required><input id="segundo" required>'
      document.body.appendChild(f)
      f.reportValidity()
    JS
    assert_equal "Completá este campo.", mensaje_de("#primero")

    page.execute_script(<<~JS)
      document.getElementById("segundo").value = "lleno por JS, sin input"
      const primero = document.getElementById("primero")
      primero.value = "escrito"
      primero.dispatchEvent(new Event("input", { bubbles: true }))
    JS

    assert page.evaluate_script(%(document.getElementById("prueba-avisos").checkValidity()))
  end

  test "F8 sin descripción no graba; con descripción sí" do
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    tracking = "1ZC3003SISTEMA2"
    find("#paquete_tracking").set(tracking)
    elegir_juan("etiquetar")

    tecla(:f8)
    assert_equal "paquete_descripcion", foco_actual
    sleep 0.5
    assert_equal 0, Paquete.where(tracking: tracking).count

    find("#paquete_descripcion").set("Ropa")
    tecla(:f8)
    assert_text "guardado exitosamente", wait: 10
    assert_equal "Ropa", Paquete.find_by(tracking: tracking)&.descripcion
  end

  test "Enter sobre la pistola sigue pasando de campo, aunque falte la descripción" do
    # «Enter no guarda»: con un campo obligatorio vacío más abajo, el Enter del
    # tracking no puede convertirse en un intento de envío.
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    campo = find("#paquete_tracking")
    campo.send_keys("1ZC3003SISTEMA3", :enter)

    assert_not_equal "paquete_tracking", foco_actual, "el Enter no avanzó"
    assert_equal 0, Paquete.where(tracking: "1ZC3003SISTEMA3").count
  end

  test "la gemela: en Entrega Personal F9 sin contenido tampoco abre el modal" do
    visit new_entrega_personal_path
    assert_selector "form", wait: 5
    elegir_juan("entrega-personal")

    find("button", text: "Guardar + Imprimir", match: :first).click

    assert_no_selector "[data-entrega-personal-target='etiquetasModal'][open]", wait: 1
    assert_equal "paquete_descripcion", foco_actual
  end

  private

  # A lo que tenga el foco, como la pistola o el operario. `page.send_keys`
  # exige que el elemento activo sea «interactuable», y después de elegir el
  # cliente del dropdown a veces no lo es para Selenium aunque sí para Chrome.
  def tecla(k)
    page.driver.browser.action.send_keys(k).perform
  end

  def elegir_juan(controlador)
    find("[data-#{controlador}-target='clienteInput']").set("Juan")
    find("[data-#{controlador}-target='clienteDropdown'] *", match: :first, wait: 5).click
  end

  def mensaje_de(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).validationMessage")
  end

  def foco_actual
    page.evaluate_script("document.activeElement && document.activeElement.id")
  end
end
