require "application_system_test_case"

# PR-C29.10 · /medicion en dos columnas, medido en Chrome.
#
# Jorge, 2026-10-08: *"the part for medir should be on the right"*, y *"the
# button Agregar volumen (F5) is too flat, it needs to be easy to press on a
# touch screen"*. Antes de eso, en PR-C29.8: *"esta parte está montada con
# otro título… no se mira bien"*.
#
# Todo lo que se prueba acá es **dónde cae cada cosa en la pantalla**, y eso
# no lo dice el HTML: lo dice el navegador. Por eso se mide con
# `getBoundingClientRect` y no se mira ninguna clase. Se probó rompiéndolo:
# una columna sola, el botón en `size: :md`, y la columna de medir sin
# `sticky`; cada uno pone rojo su test.
class MedicionDosColumnasTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
    @cajas = 10.times.map do |i|
      p = Paquete.create!(tracking: "1ZCOLUMNAS0000#{i.to_s.rjust(2, "0")}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                          sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                          descripcion: "Zapatos", peso: 2)
      p.update!(estado: "en_aduana")
      p
    end
  end

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  # 820 es una laptop chica (por encima de `md`); 1400, la pantalla grande. En
  # las dos, lo que se teclea está a la derecha de la pistola y en la misma
  # franja: no debajo.
  [ 820, 1400 ].each do |ancho|
    test "con #{ancho} px medir va a la derecha de escanear" do
      page.driver.browser.manage.window.resize_to(ancho, 1000)
      abrir_con(1)

      pistola = caja_de("#codigo_medicion")
      peso = caja_de("#medicion_peso")
      assert_operator peso["left"], :>=, pistola["right"],
                      "el peso no está a la derecha de la pistola (#{peso['left']} < #{pistola['right']})"
      assert_operator peso["top"], :<, pistola["bottom"] + 200,
                      "el peso quedó debajo de la columna de escanear"
    end
  end

  test "antes de escanear, la columna de medir dice qué va a pasar ahí" do
    visit medicion_index_path

    assert_selector "[data-medicion-target=medirVacio]", text: "Acá se pesa y se mide"
    assert_no_selector "#medicion_peso"
  end

  test "el título no se monta encima de «Peso real»" do
    abrir_con(1)

    titulo = caja_de("h4:has([data-medicion-target=rotuloVolumen])")
    peso = caja_de("label[for=medicion_peso]")
    assert_operator titulo["bottom"], :<=, peso["top"],
                    "el título termina en #{titulo['bottom']} y «Peso real» empieza en #{peso['top']}: están encimados"
  end

  # Un blanco de dedo: 56 px de alto y todo el ancho de la columna. Era un
  # `size: :md` de unos 36 px metido en el renglón de «Volúmenes guardados».
  test "«Agregar volumen» se aprieta con el dedo" do
    abrir_con(1)

    boton = caja_de("[data-medicion-target=agregarVolumen]")
    columna = caja_de("[data-medicion-target=form]")
    assert_operator boton["bottom"] - boton["top"], :>=, 56, "el botón mide #{boton['bottom'] - boton['top']} px de alto"
    assert_operator boton["right"] - boton["left"], :>=, (columna["right"] - columna["left"]) - 1,
                    "el botón no ocupa el ancho de la columna"
  end

  # La lista de lo escaneado crece a la izquierda; el peso no se puede ir de
  # la pantalla mientras se baja a verla.
  test "con la lista larga, el peso y «Guardar» se quedan a la vista al bajar" do
    page.driver.browser.manage.window.resize_to(1400, 700)
    abrir_con(@cajas.size)

    # Se baja hasta que la última caja escaneada quede al pie de la pantalla.
    # Lo que se desplaza no es `window` sino el `<main>` del layout (es el que
    # tiene `overflow`), y `sticky` se pega contra él.
    bajado = page.evaluate_script(<<~JS)
      (function () {
        var main = document.querySelector("main");
        var ultima = document.querySelector("[data-medicion-target=mesa] li:last-child");
        main.scrollTop += ultima.getBoundingClientRect().bottom - main.getBoundingClientRect().bottom + 16;
        return main.scrollTop;
      })()
    JS
    assert_operator bajado, :>, 0, "no hubo nada que bajar: la prueba no prueba nada"

    alto = page.evaluate_script("window.innerHeight")
    peso = caja_de("#medicion_peso")
    assert_operator peso["top"], :>=, 0, "el peso se fue para arriba (top #{peso['top']})"
    assert_operator peso["bottom"], :<=, alto, "el peso se fue para abajo (bottom #{peso['bottom']} de #{alto})"

    # Y el que cierra la tanda tampoco: la columna tiene tope de alto y la
    # barra va pegada a su pie.
    guardar = caja_de("[data-medicion-target=guardar]")
    assert_operator guardar["bottom"], :<=, alto, "«Guardar e imprimir» quedó abajo del pliegue (bottom #{guardar['bottom']} de #{alto})"
  end

  test "el título dice qué volumen se está midiendo" do
    abrir_con(1)
    assert_selector "[data-medicion-target=rotuloVolumen]", text: /\AVolumen 1\z/i

    find("#codigo_medicion").send_keys(:enter)
    send_keys "10", :enter, "10", :enter, "10", :enter, "10"
    page.driver.browser.action.send_keys(:f5).perform

    assert_selector "[data-medicion-target=listaVolumenes] li", count: 1, wait: 5
    assert_selector "[data-medicion-target=rotuloVolumen]", text: /\AVolumen 2\z/i
  end

  private

  def abrir_con(cuantas)
    visit medicion_index_path
    @cajas.first(cuantas).each_with_index do |caja, i|
      find("#codigo_medicion").send_keys(caja.tracking, :enter)
      assert_selector "[data-medicion-target='mesa'] li", count: i + 1, wait: 5
    end
  end

  def caja_de(selector)
    page.evaluate_script(<<~JS)
      (function () {
        var r = document.querySelector(#{selector.to_json}).getBoundingClientRect();
        return { top: r.top, bottom: r.bottom, left: r.left, right: r.right };
      })()
    JS
  end
end
