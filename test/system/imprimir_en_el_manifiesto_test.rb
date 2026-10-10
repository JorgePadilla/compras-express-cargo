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

  # Era el que no volvía: redirigía a las 4×6 sin `volver=1`, y al terminar la
  # pestaña intentaba `window.close()` sobre una pestaña que no abrió ningún
  # script —el navegador se niega— y el operario quedaba mirando etiquetas.
  test "«Finalizar e Imprimir» imprime las 4×6 y vuelve al manifiesto finalizado" do
    visit manifiesto_path(@manifiesto)

    # «Node with given id does not belong to the document», con la máquina
    # cargada (QA, 2026-10-09). El botón es un `button_to` con
    # `turbo_confirm`: si el clic llega **antes** de que Turbo y el modal de
    # confirmar monten, el form se manda derecho, sin preguntar, y la página
    # se va. `confirmando` esperaba el `confirm` nativo, no lo encontraba, y
    # buscaba el modal de HTML en la ficha que se estaba yendo: el nodo que
    # encontraba era del documento viejo. Así que primero la ficha armada —el
    # camino del confirm queda siempre el mismo— y después el clic.
    assert_eventualmente("la ficha no terminó de montar Turbo y el modal de confirmar") do
      documento_cargado?("!!window.Turbo && typeof window.cecConfirm === 'function'")
    end

    # Las acciones salen dos veces (arriba y abajo de la ficha): la de arriba.
    # Con una consulta y no con `within`, para no sostener un nodo de la ficha
    # mientras el clic se la lleva.
    imprime_y_vuelve do
      confirmando { find("#manifiesto-acciones-arriba :is(a, button)", text: "Finalizar e Imprimir").click }
    end
    assert_text "finalizado y bloqueado", wait: 5
  end

  private

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    # Una consulta, por lo mismo que arriba: «Confirmar» también se lleva la
    # página.
    if page.has_css?(MODAL_CONFIRMAR, wait: 3)
      find("#{MODAL_CONFIRMAR} :is(a, button)", text: "Confirmar").click
    end
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

  # A la 4×6 se llega en dos pasos: Turbo pide el redirect del PATCH, ve
  # `turbo-visit-control: reload` (`layouts/etiqueta_4x6`) y el navegador la
  # carga entera. Mientras tanto la página de antes sigue ahí, y preguntarle
  # algo puede tocar un nodo que está por morir. Y el `afterprint` lo escucha
  # un listener que se arma en `onload`: disparado antes, no vuelve nadie.
  #
  # La 4×6 de verdad es la que no tiene Turbo (ese layout no carga la app) y
  # terminó de cargar. Recién ahí se mira la URL y se imprime. (Trazado en
  # Chrome: entre el clic y eso no hay ningún estado intermedio con `.bulto`
  # y Turbo a la vez, así que esto no deja pasar nada que antes pasara.)
  def imprime_y_vuelve
    yield
    assert_eventualmente("la 4×6 no terminó de cargar entera", wait: 10) do
      documento_cargado?("typeof window.Turbo === 'undefined' && !!document.querySelector('.bulto')")
    end
    assert_includes page.current_url, "print=true", "la etiqueta llegó sin el diálogo de impresión"
    assert_includes page.current_url, "volver=1", "la etiqueta no sabe a dónde volver"

    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    # Volver es otra navegación entera (`location.replace`): se espera la
    # ficha cargada antes de mirarla, no solo la URL, que cambia antes.
    assert_eventualmente("no volvió a la ficha del manifiesto", wait: 10) do
      documento_cargado?("location.pathname === #{manifiesto_path(@manifiesto).to_json} && " \
                         "!!document.getElementById('manifiesto-acciones-arriba')")
    end
    assert_current_path manifiesto_path(@manifiesto)
  end

  # Mientras el documento se está cambiando, preguntarle algo puede reventar
  # en vez de contestar que no: eso también es «todavía no».
  def documento_cargado?(condicion)
    page.evaluate_script("document.readyState === 'complete' && (#{condicion})")
  rescue Selenium::WebDriver::Error::WebDriverError
    false
  end
end
