require "application_system_test_case"

# PR-C6.4: la ventana de impresión se cierra sola.
#
# Yusef, 2026-08-08, después de darle F9:
#
#   "Esto que ves acá debería de cerrarse."
#
# Con F9 la etiqueta se abre en pestaña nueva (`window.open` desde
# `eventTargetConnected`), se imprime, y quedaba abierta. En un lote de 100
# paquetes se le juntaban 100 pestañas — y en Miami trabajan a mano llena, sin
# tiempo de andar cerrando cosas.
#
# El ciclo completo que pidió: F9 → imprime → se cierra → `/etiquetar` limpio.
class EtiquetaCierraVentanaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @paquete = paquetes(:disponible_entrega_juan)
  end

  # Qué cubre este test y qué no, porque importa:
  #
  # Chrome headless dispara `beforeprint` pero **nunca `afterprint`** — no hay
  # diálogo de impresión que cerrar. Se verificó con una prueba directa. Así
  # que el ciclo completo (imprimir de verdad → el navegador avisa → cerrar) no
  # se puede observar acá.
  #
  # Lo que sí se prueba es todo lo que es código nuestro: que el listener quede
  # registrado y que **cuando el evento llega, la ventana se cierre**. Que el
  # navegador dispare `afterprint` al salir del diálogo es comportamiento
  # estándar y documentado.
  #
  # Lo único que queda para verificación manual en `:3090` es imprimir de
  # verdad y ver la pestaña desaparecer.
  test "cuando termina la impresion la ventana se cierra" do
    abrir_etiqueta_en_pestana(print: true)

    en_la_pestana_de_la_etiqueta do
      assert_selector ".etq", wait: 5
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    end

    assert_no_ventana_extra
  end

  test "cancelar la impresion tambien cierra" do
    # `afterprint` dispara igual si canceló. Los dos casos cierran: lo que
    # Yusef quiere es volver a escanear, no decidir.
    abrir_etiqueta_en_pestana(print: true)

    en_la_pestana_de_la_etiqueta do
      assert_selector ".etq", wait: 5
      # Salir del modo impresión sin haber impreso.
      page.execute_script(<<~JS)
        var mq = window.matchMedia("print")
        if (mq.dispatchEvent) {
          var e = new Event("change"); e.matches = false; mq.dispatchEvent(e)
        }
        window.dispatchEvent(new Event("afterprint"))
      JS
    end

    assert_no_ventana_extra
  end

  test "sin print=true no se arma el cierre automatico" do
    # Es la vista de revisión: entrar a ver una etiqueta no debe cerrarse en la
    # cara de nadie, ni siquiera si algo dispara `afterprint`.
    abrir_etiqueta_en_pestana(print: false)

    en_la_pestana_de_la_etiqueta do
      assert_selector ".etq", wait: 5
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")
      sleep_corto
    end

    assert_equal 2, page.driver.browser.window_handles.size,
                 "cerró una ventana que nadie mandó a imprimir"
  ensure
    cerrar_pestanas_extra
  end

  test "una etiqueta abierta pegando la URL no se cierra sola" do
    # Honestidad sobre qué protege esto: el navegador **ya** se niega a cerrar
    # pestañas que no abrió por script, así que este test pasa igual aunque se
    # quite el chequeo de `window.opener` del layout. Se queda porque fija el
    # comportamiento observable — pegar el link no te cierra la pestaña — no
    # porque pruebe nuestro guard.
    visit "#{etiqueta_paquete_path(@paquete)}?print=true"
    assert_selector ".etq", wait: 5

    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    sleep_corto

    assert_selector ".etq", wait: 5
  end

  private


  # Replica lo que hace `eticarquetar_controller.js#eventTargetConnected`:
  # `window.open(..., "_blank")`, que es lo que deja `window.opener` seteado.
  def abrir_etiqueta_en_pestana(print:)
    visit paquetes_path
    url = etiqueta_paquete_path(@paquete)
    url += "?hermanas=1&print=true" if print
    page.execute_script("window.open('#{url}', '_blank')")
  end

  # Corre el bloque dentro de la pestaña que abrió `window.open`, y vuelve a la
  # principal si sigue existiendo (la del cierre no sigue existiendo).
  def en_la_pestana_de_la_etiqueta
    b = page.driver.browser
    principal = b.window_handles.first
    etiqueta = b.window_handles.last
    raise "no se abrió la pestaña de la etiqueta" if etiqueta == principal

    b.switch_to.window(etiqueta)
    yield
  ensure
    b.switch_to.window(principal) if b.window_handles.include?(principal)
  end

  def assert_no_ventana_extra
    handles = page.driver.browser.window_handles
    Timeout.timeout(10) do
      loop do
        break if page.driver.browser.window_handles.size == 1
        sleep 0.2
      end
    end
  rescue Timeout::Error
    flunk "la ventana de impresión sigue abierta (#{handles.size} pestañas)"
  end

  def sleep_corto
    sleep 1.5
  end
end
