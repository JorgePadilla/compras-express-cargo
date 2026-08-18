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
end
