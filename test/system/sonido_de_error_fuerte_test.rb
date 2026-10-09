require "application_system_test_case"

# PR-C29.9 · El error, medido en el navegador de verdad.
#
# Jorge, 2026-10-08: *"el audio de error creo que tiene que ser más cruel,
# fuerte, molesto, intenso"*. «Fuerte» y «áspero» se pueden medir: se toca el
# tono por el mismo `audio_controller` que suena en la bodega, pero contra un
# `OfflineAudioContext`, que en vez de mandarlo al parlante devuelve las
# muestras. Se compara contra el tono limpio de `_playTone` —el que era el
# error antes, y que siguen usando `success`, `notify` y `alert`— a la misma
# nota, la misma duración y el mismo volumen.
#
# `test/lib/sonidos_wav_test.rb` fija lo mismo para los .wav; esto fija que el
# navegador haga la misma cuenta, que es lo que oye el operario.
class SonidoDeErrorFuerteTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
    visit medicion_index_path
    assert_selector "[data-controller~='audio']", visible: :all, wait: 5
  end

  test "el error suena mucho más fuerte que el tono limpio, sin pasarse del volumen" do
    m = medir

    assert_nil m["falla"], "no se pudo medir: #{m['falla']}"
    assert_operator m["error"]["rms"], :>, 2.5 * m["limpio"]["rms"],
                    "el error tiene que sonar bastante más fuerte que el «tic» de antes " \
                    "(error #{m['error']['rms'].round(3)} vs limpio #{m['limpio']['rms'].round(3)})"
    # El volumen del usuario es el techo: 60 → 0.6. La saturación aplasta
    # contra ese techo, no lo atraviesa.
    assert_operator m["error"]["pico"], :<=, 0.6 + 0.01
  end

  test "el tono limpio sigue siendo el de antes: los avisos no se vuelven ásperos" do
    m = medir

    # Una cuadrada sola que cae desde la primera muestra: poca energía. Si esto
    # sube, alguien le puso la voz del error a `success`/`notify`/`alert`.
    assert_operator m["limpio"]["rms"], :<, 0.2
  end

  private

  # El resultado vuelve como **texto JSON** y se parsea acá. Devolviendo el
  # objeto directo, chromedriver se caía con un `WebDriverError` sin mensaje
  # (los números salen de un `Float32Array`); como texto llega entero.
  def medir
    crudo = page.driver.browser.execute_async_script(<<~JS)
      var listo = arguments[arguments.length - 1];
      var el = document.querySelector("[data-controller~='audio']");
      var audio = window.Stimulus.getControllerForElementAndIdentifier(el, "audio");

      function muestras(tocar) {
        var ctx = new OfflineAudioContext(1, Math.round(44100 * 0.3), 44100);
        audio._audioContext = ctx;
        audio._cadenaError = null;
        tocar();
        return ctx.startRendering().then(function (buffer) {
          var datos = buffer.getChannelData(0), suma = 0, pico = 0;
          for (var i = 0; i < datos.length; i++) {
            suma += datos[i] * datos[i];
            pico = Math.max(pico, Math.abs(datos[i]));
          }
          return { rms: Math.sqrt(suma / datos.length), pico: pico };
        });
      }

      var limpio;
      muestras(function () { audio._playTone(200, 0.3); })
        .then(function (r) { limpio = r; return muestras(function () { audio._playErrorTone(200, 0.3); }); })
        .then(function (error) { listo(JSON.stringify({ limpio: limpio, error: error })); })
        .catch(function (e) { listo(JSON.stringify({ falla: String(e) })); });
    JS
    JSON.parse(crudo)
  end
end
