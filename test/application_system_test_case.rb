require "test_helper"

# Un Chrome como el de la calle: **con** el bloqueador de popups.
#
# Chromedriver arranca Chrome con `--disable-popup-blocking`, así que en los
# system tests un `window.open` sin ningún gesto del usuario abre igual y dos
# seguidas abren dos. Con ese navegador, un test sobre popups da verde aunque el
# navegador de verdad se coma la ventana — que es exactamente cómo se nos pasó
# el Warehouse Receipt que Yusef nunca vio.
#
# Va como driver **con nombre propio** y no como un bloque en `driven_by`: un
# `driven_by :selenium` por clase no alcanza, porque Capybara reusa la sesión
# —y por lo tanto el navegador— de la primera clase que haya corrido. Se
# comprobó: en `bin/rails test test/system` completo, la clase con el bloque
# heredaba el Chrome permisivo. Con un nombre distinto, el navegador es otro.
Capybara.register_driver :chrome_con_bloqueador_de_popups do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--window-size=1400,1400")
  options.exclude_switches = [ "disable-popup-blocking" ]
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # ── Hacer observable una carrera ────────────────────────────────────────
  #
  # El servidor de test contesta más rápido de lo que Capybara teclea, así que
  # las carreras entre el teclado y una respuesta **no existen** salvo que se
  # las provoque. Estos dos helpers monkeypatchean `window.fetch` para eso.
  #
  # Salieron de `etiquetar_escaneo_rapido_test` (PR-C6.21), donde ya había uno
  # así para el tracking; C20-10 los necesitó también para el autocomplete, y
  # duplicarlos habría sido la tercera copia de la misma idea.

  # Todas las respuestas que matcheen `patron` llegan tarde. Es la latencia de
  # verdad: sirve para adelantársele al dropdown con el teclado.
  def demorar(patron, ms: 800)
    page.execute_script(<<~JS, patron, ms)
      const patron = arguments[0], ms = arguments[1]
      const original = window.fetch
      window.fetch = function (...args) {
        const promesa = original.apply(this, args)
        if (!String(args[0]).includes(patron)) return promesa
        return promesa.then((r) => new Promise((resolver) => setTimeout(() => resolver(r), ms)))
      }
    JS
  end

  # Solo la PRIMERA respuesta llega tarde, y avisa cuando la suelta. Es el
  # orden de llegada invertido: la vieja aterriza después de la nueva.
  def retener_la_primera(patron, ms: 1500)
    page.execute_script(<<~JS, patron, ms)
      const patron = arguments[0], ms = arguments[1]
      window.__respuestaTardia = false
      const original = window.fetch
      let consultas = 0
      window.fetch = function (...args) {
        const promesa = original.apply(this, args)
        if (!String(args[0]).includes(patron)) return promesa
        consultas += 1
        if (consultas !== 1) return promesa
        return promesa.then((r) => new Promise((resolver) => {
          setTimeout(() => { window.__respuestaTardia = true; resolver(r) }, ms)
        }))
      }
    JS
  end

  def esperar_respuesta_tardia(segundos: 5)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    until page.evaluate_script("window.__respuestaTardia === true")
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite

      sleep 0.1
    end
  end
end
