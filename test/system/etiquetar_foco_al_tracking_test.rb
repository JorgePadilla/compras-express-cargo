require "application_system_test_case"

# C19-02. Yusef, 2026-08-28, con el papel de su equipo:
#
#   "Después de darle F9, sale la etiqueta, imprime… lo que le hace falta es
#    que el cursor… regrese a donde está el [campo de] tracking."
#   "No sé dónde va, se queda como en el aire… la ventaja de eso es que ellos
#    ya solo vienen y escanean el siguiente."
#
# El foco se perdía por dos vías que acá se prueban por separado:
#
#   · `clearForm()` tras guardar — enfocaba, pero si el modal rojo de la bolsa
#     estaba abierto la página era inerte y el focus() moría en silencio; el
#     modal, al cerrarse, no devolvía el foco a ningún lado.
#   · la pestaña de impresión roba el foco de la **ventana**; cuando se cierra
#     nadie re-enfocaba el campo. Esa mitad (el listener de window "focus") no
#     se puede observar en headless —cerrar la pestaña no dispara "focus" en
#     la principal— y queda para la verificación manual en :3090.
class EtiquetarFocoAlTrackingTest < ApplicationSystemTestCase
  setup do
    @cliente = clientes(:juan)
    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "despues de guardar con impresion el foco queda en el tracking" do
    find("#paquete_tracking").set("1Z999FOCO#{SecureRandom.hex(3).upcase}")
    elegir_cliente
    find("[data-caja-campo='peso']").set("10")

    antes = Paquete.count
    click_on "Guardar + Imprimir", match: :first
    esperar { Paquete.count == antes + 1 }

    # Si salió el aviso rojo de la bolsa, cerrarlo — el foco vuelve por ahí.
    cerrar_aviso_de_bolsa_si_salio

    assert_foco_en_tracking
  ensure
    cerrar_pestanas_extra
  end

  test "cerrar el aviso rojo de la bolsa devuelve el foco al tracking" do
    # El aviso se dispara directo: probar el cierre no necesita el guardado, y
    # así este test no depende de si el cliente trae sucursal de retiro.
    page.execute_script(<<~JS)
      const ctrl = window.Stimulus.getControllerForElementAndIdentifier(
        document.querySelector("[data-controller~='etiquetar']"), "etiquetar")
      ctrl._sucursalActual = "SAN PEDRO SULA"
      ctrl._avisarLaBolsa = true
      ctrl._avisarSucursalAlFinal()
    JS
    assert_selector "dialog[data-etiquetar-target='sucursalModal'][open]", wait: 5

    find("dialog[data-etiquetar-target='sucursalModal'] button").click

    assert_foco_en_tracking
  end

  private

  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5
  end

  def abrir_etiquetar
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  def elegir_cliente
    page.execute_script(
      "document.querySelector('[data-etiquetar-target=clienteId]').value = arguments[0]",
      @cliente.id
    )
  end

  def cerrar_aviso_de_bolsa_si_salio
    if page.has_selector?("dialog[data-etiquetar-target='sucursalModal'][open]", wait: 2)
      find("dialog[data-etiquetar-target='sucursalModal'] button").click
    end
  end

  def assert_foco_en_tracking
    activo = nil
    50.times do
      activo = page.evaluate_script("document.activeElement && document.activeElement.id")
      break if activo == "paquete_tracking"
      sleep 0.1
    end
    assert_equal "paquete_tracking", activo, "el foco quedó en: #{activo.inspect}"
  end

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end

  def cerrar_pestanas_extra
    b = page.driver.browser
    principal = b.window_handles.first
    b.window_handles[1..].to_a.each do |h|
      b.switch_to.window(h)
      b.close
    end
    b.switch_to.window(principal)
  end
end
