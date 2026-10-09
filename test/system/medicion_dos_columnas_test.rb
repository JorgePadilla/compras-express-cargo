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

  # PR-C29.11 · Jorge: *"it seems like the scanning, the left part, is the one
  # that should be a little bigger"*. Desde `lg` escanear se lleva más ancho,
  # y medir no puede quedar tan angosta que no entren las tres medidas. 1024
  # con un volumen es el caso que salía al revés con `fr` a secas.
  # PR-C29.14 · Jorge pidió medir un 20 % más angosta: un tercio del ancho.
  [ 1024, 1400 ].each do |ancho|
    test "con #{ancho} px escanear es más ancha que medir, y medir sigue entrando" do
      page.driver.browser.manage.window.resize_to(ancho, 1000)
      abrir_con(1)
      # Con un volumen guardado: su renglón, con los dos botones de 48, es lo
      # que más empuja el ancho propio de medir.
      agregar_un_volumen

      escanear = caja_de("#codigo_medicion", cerca: ".rounded-lg.shadow")
      medir = caja_de("#medicion_peso", cerca: ".rounded-lg.shadow")
      ancho_escanear = escanear["right"] - escanear["left"]
      ancho_medir = medir["right"] - medir["left"]
      assert_operator ancho_escanear, :>, ancho_medir, "escanear mide #{ancho_escanear} y medir #{ancho_medir}"

      # PR-C29.14 · Medir es un tercio del ancho, no más (era 3/7, ~43 %).
      parte = ancho_medir / (ancho_escanear + ancho_medir)
      assert_in_delta 0.34, parte, 0.03, "medir ocupa el #{(parte * 100).round} % del ancho"

      # …y las tres medidas siguen entrando lado a lado, con lugar para
      # «12.50» en letra grande.
      %w[alto largo ancho].each do |medida|
        campo = caja_de("#medicion_#{medida}")
        assert_operator campo["right"] - campo["left"], :>=, 64, "el campo #{medida} quedó de #{campo['right'] - campo['left']} px"
      end
    end
  end

  # PR-C29.11 · Jorge: *"all actionable in medicion should be easy to touch in
  # a touch screen"*. Con la tanda armada y un volumen guardado —que es cuando
  # están a la vista casi todos—, todo lo que se aprieta mide 48 px o más. Lo
  # de los modales lo cuida `test/lint/medicion_tactil_test.rb`. Se mira la
  # pantalla y no el marco del layout (el sol del tema oscuro, la barra
  # lateral), que es el mismo en todas.
  test "todo lo que se aprieta a la vista mide 48 px o más" do
    abrir_con(2)
    agregar_un_volumen

    chicos = page.evaluate_script(<<~JS)
      Array.from(document.querySelector("[data-controller~=medicion]").querySelectorAll("button, input:not([type=hidden]), select, a[href]"))
        .filter(function (el) { return el.offsetParent !== null })
        .map(function (el) { var r = el.getBoundingClientRect(); return { que: (el.getAttribute("aria-label") || el.textContent || el.id || el.name).trim().slice(0, 40), alto: r.height, ancho: r.width } })
        .filter(function (x) { return x.alto < 47.5 || x.ancho < 47.5 })
    JS
    assert_empty chicos, "estos se aprietan y miden menos de 48 px: #{chicos.inspect}"
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

  def agregar_un_volumen
    find("#codigo_medicion").send_keys(:enter)
    send_keys "10", :enter, "10", :enter, "10", :enter, "10"
    page.driver.browser.action.send_keys(:f5).perform
    assert_selector "[data-medicion-target=listaVolumenes] li", count: 1, wait: 5
  end

  # `cerca:` sube con `closest` hasta la caja que importa: la tarjeta de la
  # columna, no el campo.
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
