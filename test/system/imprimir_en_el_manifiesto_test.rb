require "application_system_test_case"

# Todos los botones que imprimen en la ficha del manifiesto, apretados.
#
# Jorge, 2026-10-08: *"cuando guarda imprime o solo imprime siempre se tiene
# que abrir el preview para imprimir; una vez se imprime se regresa a la vista
# previa. Revisa todos los botones donde se imprime"*.
#
# Son dos familias, y cada una vuelve distinto:
#
#   · **Pestaña nueva** (las hojas y las 4×6 sueltas): se abre con
#     `?print=true`, imprime, y al terminar **se cierra** — la ficha del
#     manifiesto quedó abierta en la pestaña de atrás.
#   · **Misma pestaña** (lo que nace de un guardar: agregar, corregir,
#     finalizar): la etiqueta se lleva esta pestaña con `?print=true&volver=1`
#     y al terminar **vuelve a la ficha**.
#
# Chrome headless nunca dispara `afterprint` (ver `etiqueta_cierra_ventana_test`),
# así que acá se dispara a mano: lo que se prueba es que cada botón llegue con
# la impresión armada y que, cuando el navegador avisa, la pantalla vuelva.
class ImprimirEnElManifiestoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:supervisor_miami))

    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami))
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:supervisor_miami))

    @paquete = paquetes(:recibido)
    @paquete.tareas.update_all(estado: "realizada")
    @paquete.update_columns(manifiesto_id: @manifiesto.id, caja_manifiesto_id: @caja.id)
  end

  teardown { cerrar_pestanas_extra }

  # ── Pestaña nueva: imprime y se cierra ─────────────────────────────────

  test "«Imprimir manifiesto» abre la hoja con el diálogo y al terminar se cierra" do
    imprime_en_pestana_nueva { click_on "Imprimir manifiesto" }
  end

  # La tecla del botón la aprieta el controller global (`data-shortcut`), con
  # el foco afuera de cualquier campo. Es la misma pestaña nueva que el clic.
  test "F4 hace lo mismo que «Imprimir manifiesto»" do
    imprime_en_pestana_nueva do
      find("body").click
      page.driver.browser.action.send_keys(:f4).perform
    end
  end

  test "«Imprimir listado» abre el listado con el diálogo y al terminar se cierra" do
    imprime_en_pestana_nueva { click_on "Imprimir listado" }
  end

  test "«Imprimir las 4×6» abre las etiquetas con el diálogo y al terminar se cierra" do
    imprime_en_pestana_nueva { click_on "Imprimir las 4×6" }
  end

  test "la impresora de la fila abre la 4×6 de esa caja y al terminar se cierra" do
    imprime_en_pestana_nueva { find("a[aria-label='Imprimir la etiqueta de la caja #{@caja.letra}']").click }
  end

  # ── Misma pestaña: imprime y vuelve a la ficha ─────────────────────────

  test "«Agregar e imprimir» imprime la caja nueva y vuelve al manifiesto" do
    visit manifiesto_path(@manifiesto)
    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "7"

    imprime_y_vuelve { click_on "Agregar e imprimir" }
  end

  test "«Guardar e imprimir» al corregir una caja imprime y vuelve al manifiesto" do
    visit manifiesto_path(@manifiesto)
    find("button[aria-label='Editar la caja #{@caja.letra}']").click
    fill_in "caja_manifiesto_peso", with: "41"

    imprime_y_vuelve { click_on "Guardar e imprimir" }
    assert_equal 41, @caja.reload.peso.to_i
  end

  # PR-C29.7: era el que no volvía —redirigía a las 4×6 sin `volver=1` y el
  # operario quedaba mirando etiquetas—.
  #
  # C30-05: y además imprimía lo que no era. Yusef: *"lo que tiene que
  # imprimirme no es esta etiqueta… el que necesito que me imprima después de
  # finalizado es este"* — la hoja del manifiesto. La vuelta es la misma.
  test "«Finalizar e Imprimir» imprime la hoja del manifiesto y vuelve al manifiesto finalizado" do
    visit manifiesto_path(@manifiesto)

    # Las acciones salen dos veces (arriba y abajo de la ficha): la de arriba.
    imprime_y_vuelve(en: HOJA_DEL_MANIFIESTO) do
      confirmando { within("#manifiesto-acciones-arriba") { click_on "Finalizar e Imprimir" } }
    end
    assert_text "finalizado y bloqueado", wait: 5
  end

  test "«Finalizar e Imprimir» sin bultos también imprime la hoja y vuelve" do
    # El manifiesto armado sin escanear (`C23-10`) no tiene cajas. Antes el
    # botón ni aparecía: lo único que había para imprimir eran 4×6.
    @paquete.update_columns(caja_manifiesto_id: nil)
    @caja.destroy!
    visit manifiesto_path(@manifiesto)

    imprime_y_vuelve(en: HOJA_DEL_MANIFIESTO) do
      confirmando { within("#manifiesto-acciones-arriba") { click_on "Finalizar e Imprimir" } }
    end
    assert_text "finalizado y bloqueado", wait: 5
  end

  private

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end

  def imprime_en_pestana_nueva
    visit manifiesto_path(@manifiesto)
    nueva = window_opened_by { yield }

    within_window(nueva) do
      assert_includes page.current_url, "print=true", "la hoja se abrió sin el diálogo de impresión"
      assert_no_ventana_extra_despues_de_imprimir
    end
  rescue Selenium::WebDriver::Error::NoSuchWindowError
    # La pestaña se cerró sola adentro del `within_window`: es lo que se quería.
    nil
  ensure
    assert_equal 1, page.driver.browser.window_handles.size, "la pestaña de impresión sigue abierta"
  end

  def assert_no_ventana_extra_despues_de_imprimir
    assert_selector "body", wait: 5
    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    Timeout.timeout(10) { sleep 0.2 while page.driver.browser.window_handles.size > 1 }
  end

  # La hoja del manifiesto (layout `print`), por lo que dice arriba y no por
  # una clase: lo que importa es que sea ESE papel y no una 4×6.
  HOJA_DEL_MANIFIESTO = :hoja

  def imprime_y_vuelve(en: ".bulto")
    yield
    if en == HOJA_DEL_MANIFIESTO
      assert_text "MANIFIESTO DE CARGA", wait: 5
      assert_no_selector ".bulto"
    else
      assert_selector en, wait: 5
    end
    assert_includes page.current_url, "print=true", "la etiqueta llegó sin el diálogo de impresión"
    assert_includes page.current_url, "volver=1", "la etiqueta no sabe a dónde volver"

    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    assert_current_path manifiesto_path(@manifiesto), wait: 5
  end
end
