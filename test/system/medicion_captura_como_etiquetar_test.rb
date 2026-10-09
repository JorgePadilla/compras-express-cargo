require "application_system_test_case"

# PR-C29.8 · El bloque de captura de /medicion, medido en Chrome.
#
# Jorge, 2026-10-08: *"en medición esta parte está montada con otro título,
# Volumen · peso, medidas y cálculo; hay que corregir cómo se mira, no se mira
# bien; la calculadora Yusef la había pedido a la derecha"*.
#
# Lo que se rompió no se ve en el HTML: el título tenía `-mb-3` y se le subía
# encima a «Peso real», y las columnas recién arrancaban en `lg`, así que en
# la laptop táctil de la PESA la calculadora se iba abajo. Las dos cosas son de
# **dónde cae cada caja en la pantalla**, y eso solo lo dice el navegador. Por
# eso se mide con `getBoundingClientRect` y no se mira la clase.
class MedicionCapturaComoEtiquetarTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
    @paquete = Paquete.create!(tracking: "1ZCAPTURA0000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                               descripcion: "Zapatos", peso: 2)
    @paquete.update!(estado: "en_aduana")
  end

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test "el título no se monta encima de «Peso real»" do
    abrir_con_una_caja

    titulo = caja_de("h4:has([data-medicion-target=rotuloVolumen])")
    peso = caja_de("label[for=medicion_peso]")
    assert_operator titulo["bottom"], :<=, peso["top"],
                    "el título termina en #{titulo['bottom']} y «Peso real» empieza en #{peso['top']}: están encimados"
  end

  # 820 es la laptop táctil de la PESA (por encima de `md`, por debajo de `lg`);
  # 1400 es la pantalla grande. En las dos, la calculadora va a la derecha de
  # lo que se teclea y en la misma franja, no debajo.
  [ 820, 1400 ].each do |ancho|
    test "con #{ancho} px la calculadora va a la derecha de la captura" do
      page.driver.browser.manage.window.resize_to(ancho, 1000)
      abrir_con_una_caja

      campo = caja_de("#medicion_peso")
      calculo = caja_de("[data-calc-volumetrico-target=pesoCobrar]", cerca: ".p-4")
      assert_operator calculo["left"], :>=, campo["right"],
                      "la calculadora no está a la derecha del peso (#{calculo['left']} < #{campo['right']})"
      assert_operator calculo["top"], :<, campo["bottom"],
                      "la calculadora quedó debajo de la captura"
    end
  end

  test "el título dice qué volumen se está midiendo" do
    abrir_con_una_caja
    assert_selector "[data-medicion-target=rotuloVolumen]", text: /\AVolumen 1\z/i

    find("#codigo_medicion").send_keys(:enter)
    send_keys "10", :enter, "10", :enter, "10", :enter, "10"
    page.driver.browser.action.send_keys(:f5).perform

    assert_selector "[data-medicion-target=listaVolumenes] li", count: 1, wait: 5
    assert_selector "[data-medicion-target=rotuloVolumen]", text: /\AVolumen 2\z/i
  end

  private

  def abrir_con_una_caja
    visit medicion_index_path
    find("#codigo_medicion").send_keys(@paquete.tracking, :enter)
    assert_selector "[data-medicion-target='mesa'] li", count: 1, wait: 5
  end

  # `cerca:` sube con `closest` hasta la caja que importa: la calculadora es
  # la tarjeta que envuelve al peso a cobrar, no el número.
  def caja_de(selector, cerca: nil)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        #{cerca ? "el = el.closest(#{cerca.to_json});" : ""}
        var r = el.getBoundingClientRect();
        return { top: r.top, bottom: r.bottom, left: r.left, right: r.right };
      })()
    JS
  end
end
