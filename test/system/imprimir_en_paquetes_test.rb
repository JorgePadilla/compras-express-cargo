require "application_system_test_case"

# Imprimir desde «Todos los Paquetes» y desde la ficha del paquete.
#
# Jorge, 2026-10-08: *"en todos los paquetes, cuando se imprime la etiqueta no
# sale en imprimir previo sino que solo la etiqueta, corrige que salga el
# imprimir preview"*. Es la misma regla que el manifiesto (PR-C29.7): todo lo
# que dice imprimir abre el diálogo y, al terminar, la pestaña se cierra sola
# y deja al operario donde estaba.
#
# Chrome headless no dispara `afterprint` (ver `etiqueta_cierra_ventana_test`),
# así que acá se dispara a mano: lo que se prueba es que cada botón llegue con
# la impresión armada y que, cuando el navegador avisa, la pestaña se cierre.
class ImprimirEnPaquetesTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:admin))
    @paquete = paquetes(:recibido)
  end

  teardown { cerrar_pestanas_extra }

  test "la impresora de la fila en «Todos los Paquetes» abre el diálogo y se cierra" do
    visit paquetes_path
    assert_selector "a[title='Imprimir etiqueta']", wait: 5
    imprime_y_se_cierra { find("a[title='Imprimir etiqueta'][href^='#{etiqueta_paquete_path(@paquete)}']").click }
  end

  test "«Re-imprimir Etiquetas Miami» de un paquete de una caja abre el diálogo y se cierra" do
    visit paquete_path(@paquete)
    imprime_y_se_cierra { click_on "Re-imprimir Etiquetas Miami" }
  end

  test "«Warehouse Receipt» de la ficha abre el diálogo y se cierra" do
    visit paquete_path(@paquete)
    imprime_y_se_cierra { click_on "Warehouse Receipt" }
  end

  private

  def imprime_y_se_cierra
    nueva = window_opened_by { yield }
    within_window(nueva) do
      assert_selector "body", wait: 5
      assert_includes page.current_url, "print=true", "se abrió sin el diálogo de impresión"
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")
      Timeout.timeout(10) { sleep 0.2 while page.driver.browser.window_handles.size > 1 }
    end
  rescue Selenium::WebDriver::Error::NoSuchWindowError
    # Se cerró sola adentro del `within_window`: es lo que se quería.
    nil
  ensure
    assert_equal 1, page.driver.browser.window_handles.size, "la pestaña de impresión sigue abierta"
  end
end
