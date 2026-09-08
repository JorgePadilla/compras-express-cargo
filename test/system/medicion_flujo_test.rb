require "application_system_test_case"

# C26-02/03 · C27-01…C27-14 · La estación de Medición, con pistola y teclado en
# Chrome.
#
# Lo que importa acá no se ve en el JSON: que la mesa se arme **escaneando** y
# se pinte sin recargar, que el foco se quede en la pistola entre pip y pip, que
# el modal rojo salga con las dos salidas que pidió Yusef, y que al guardar se
# abra **una** impresión con tantas etiquetas como mediciones.
#
# Y desde el 2026-09-08, que la pantalla sea **una sola tarjeta** con el bloque
# de /etiquetar —Jorge: *"a Yusef le gusta el agregar que estaba en etiqueta"*—:
# la caja se ve una vez, no hay cuadritos que tocar, y «Facturar lo que hay»
# sale después de guardar, solo si el consolidado quedó incompleto.
#
# Yusef, el 2026-09-07: *"no es una etiqueta por paquete, es una etiqueta por
# medición, y la medición puede tener 100 paquetes"*.
class MedicionFlujoTest < ApplicationSystemTestCase
  setup do
    users(:medidor).update!(iniciales: "MD")
    ingresar(users(:medidor))
    @paquete = caja("1ZFLUJO00000001")
  end

  def caja(tracking, cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), estado: "en_aduana")
    p = Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envio,
                        sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                        descripcion: "Zapatos", peso: 2)
    p.update!(estado: estado)
    p.reload
  end

  def escanear(codigo) = find("#codigo_medicion").send_keys(codigo, :enter)

  # Escanear y **esperar a que la caja esté en la mesa** antes de seguir: sin
  # esto las teclas se van al campo de escaneo, que es donde queda el foco, y el
  # Enter dispara un segundo escaneo de basura.
  def escanear_a_la_mesa(paquete, cuantas)
    escanear(paquete.numero_recepcion.presence || paquete.tracking)
    assert_selector "[data-medicion-target='mesa'] li", count: cuantas, wait: 5
  end

  # C27-02 · Enter con el campo de escaneo vacío es la salida al peso: el foco
  # vive en la pistola porque el gesto normal es pip, pip, pip.
  def teclear(peso, alto, largo, ancho)
    find("#codigo_medicion").send_keys(:enter)
    assert_equal "medicion_peso", foco, "Enter en el campo vacío lleva al peso"
    send_keys peso, :enter, alto, :enter, largo, :enter, ancho
  end

  def foco = page.evaluate_script("document.activeElement.id")
  def espiar_impresion = page.execute_script("window.__abrio = null; window.open = function(u){ window.__abrio = u }")
  def lo_que_abrio = page.evaluate_script("window.__abrio").to_s

  test "una caja sola: escanear, teclear con Enter, guardar con F10, y sale su etiqueta" do
    visit medicion_index_path
    escanear(@paquete.tracking)

    assert_selector "[data-medicion-target='trabajo']", text: "Juan", wait: 5
    assert_selector "[data-medicion-target='mesaTitulo']", text: /Volumen 1 · 1 caja en la mesa/i
    assert_selector "[data-medicion-target='mesa'] li", text: @paquete.numero_recepcion
    assert_equal "codigo_medicion", foco, "el foco se queda en la pistola: la mesa se arma escaneando"

    teclear "12.5", "10", "12", "14"
    assert_nil @paquete.reload.medido_at, "nada se guardó todavía"

    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", text: "una etiqueta", wait: 5
    bulto = Bulto.last
    assert_equal 12.5, bulto.peso.to_f
    assert_equal "MD", bulto.medido_por
    assert_equal @paquete.id, bulto.paquetes.first.id
    assert_equal 2.0, @paquete.reload.peso.to_f, "a la caja no se le pisa el dato de Miami"
    assert_match %r{/medicion/sesiones/#{bulto.sesion}/etiquetas\?print=true}, lo_que_abrio
    assert_equal "codigo_medicion", foco, "la pistola queda lista para la siguiente"
  end

  # C27-01 · La regla, dicha tres veces: *"no es una etiqueta por paquete, es una
  # etiqueta por medición"*. Y el porqué: *"si yo mido esto [caja por caja], te
  # estoy cobrando espacio vacío"*.
  test "tres cajas del mismo cliente son UNA medición y UNA etiqueta" do
    segunda = caja("1ZFLUJO00000002")
    tercera = caja("1ZFLUJO00000003")

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear_a_la_mesa(segunda, 2)
    escanear_a_la_mesa(tercera, 3)

    assert_selector "[data-medicion-target='mesaTitulo']", text: /3 cajas en la mesa/i
    assert_selector "[data-medicion-target='mesa'] li", text: segunda.numero_recepcion

    teclear "40", "20", "30", "40"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", text: "3 cajas en un solo bulto", wait: 5
    assert_equal 1, Bulto.count, "tres cajas, un solo bulto"
    assert_equal 3, Bulto.first.paquetes.count
    assert_equal 40.0, Bulto.first.peso.to_f

    visit lo_que_abrio
    assert_selector ".med", count: 1, visible: :all
    assert_text "3 cajas"
  end

  # C27-05 · Yusef: *"escanea uno de Jorge y va y escanea otro y ese no es el
  # mismo Jorge… le tira error, es diferente cliente… ¿desea eliminar este
  # último o empezar todo de nuevo?"*
  test "una caja de otro cliente abre el modal rojo con sus dos salidas, y no entra a la mesa" do
    ajena = caja("1ZFLUJO00000004", cliente: clientes(:maria))

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear(ajena.tracking)

    assert_selector "dialog[open]", text: "Es otro cliente", wait: 5
    assert_selector "dialog[open]", text: clientes(:maria).nombre_completo
    assert_selector "dialog[open]", text: "Empezar todo de nuevo"
    # C20-13 · Escape no contesta un aviso: *"ellos no las leen"*.
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "Es otro cliente"

    within("dialog[open]") { click_on "Quitar el último escaneado" }

    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='mesa'] li", count: 1, text: @paquete.numero_recepcion
    assert_equal "codigo_medicion", foco
  end

  test "«empezar todo de nuevo» deja la mesa vacía" do
    ajena = caja("1ZFLUJO00000005", cliente: clientes(:maria))

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear(ajena.tracking)
    assert_selector "dialog[open]", text: "Es otro cliente", wait: 5

    within("dialog[open]") { click_on "Empezar todo de nuevo" }

    assert_no_selector "dialog[open]", wait: 5
    assert_no_selector "[data-medicion-target='mesa'] li"
  end

  # C27-01 · *"Mide y pesa este, le da agregar; mide y pesa este por separado
  # porque no cuadra… y ahí le dice imprimir, y como son dos mediciones, imprime
  # dos."* El operario les dice **volúmenes**.
  test "un segundo volumen imprime DOS etiquetas, con «1 de 2» y «2 de 2»" do
    segunda = caja("1ZFLUJO00000006")

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    teclear "20", "10", "12", "14"
    send_keys :f5

    assert_selector "[data-medicion-target='listaVolumenes'] li", count: 1, wait: 5
    assert_selector "[data-medicion-target='volumenesContador']", text: "1"
    assert_no_selector "[data-medicion-target='mesa'] li"

    escanear_a_la_mesa(segunda, 1)
    assert_selector "[data-medicion-target='mesaTitulo']", text: /Volumen 2 · 1 caja en la mesa/i
    assert_selector "[data-medicion-target='guardarTexto']", text: "Guardar e imprimir 2 etiquetas"

    teclear "8", "5", "6", "7"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", text: "2 volúmenes", wait: 5
    assert_equal 2, Bulto.count
    assert_equal [ "1 de 2", "2 de 2" ], Bulto.order(:orden).map(&:de_cuantos_texto)

    visit lo_que_abrio
    assert_selector ".med", count: 2, visible: :all
    assert_text "1 de 2"
    assert_text "2 de 2"
  end

  # C27-04 · *"Ese está consolidando con tal pre-alerta, con tal número. Ese va
  # amarrado con otra."* — *"¿desea procesar el consolidado o lo va a poner a un
  # lado para terminar el que está haciendo?"*
  test "el modal del consolidado nombra la pre-alerta, y «lo dejo de lado» sigue con lo que hay" do
    consolidada = caja("1ZFLUJO00000007")
    pa = consolidado_con(consolidada)

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear(consolidada.tracking)

    assert_selector "dialog[open]", text: "Está consolidando con otra pre-alerta", wait: 5
    assert_selector "dialog[open]", text: pa.numero_documento

    within("dialog[open]") { click_on "Lo dejo de lado" }

    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='mesa'] li", count: 1, text: @paquete.numero_recepcion
    assert_equal "codigo_medicion", foco, "el foco vuelve a la pistola: es como un F2"
  end

  test "«hago el consolidado» limpia la mesa y deja solo la consolidada" do
    consolidada = caja("1ZFLUJO00000008")
    consolidado_con(consolidada)

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear(consolidada.tracking)
    assert_selector "dialog[open]", text: "Está consolidando con otra pre-alerta", wait: 5

    within("dialog[open]") { click_on "Hago el consolidado" }

    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='mesa'] li", count: 1, text: consolidada.numero_recepcion
    assert_no_selector "[data-medicion-target='mesa'] li", text: @paquete.numero_recepcion
  end

  # C27-09 · *"Él va a poder reimprimir la etiqueta, porque digamos que si se le
  # cae… ¿cómo la buscaría? Tendría que volver a escanear el warehouse."*
  test "escanear una caja ya medida ofrece reimprimir su etiqueta" do
    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    teclear "20", "10", "12", "14"
    # Se espía **antes** del F10, no después: un `window.open` de verdad deja
    # una ventana huérfana que después le tira flakes al resto de la suite.
    espiar_impresion
    send_keys :f10
    assert_selector "[data-medicion-target='banner']", wait: 5

    espiar_impresion
    escanear(@paquete.tracking)

    assert_selector "dialog[open]", text: "Esta caja ya está medida", wait: 5
    within("dialog[open]") { click_on "Reimprimir la etiqueta" }

    assert_no_selector "dialog[open]", wait: 5
    assert_equal etiqueta_bulto_medicion_path(Bulto.last, print: "true"), lo_que_abrio
  end

  # C27-33 · Yusef: *"se equivocan y lo ingresan en seis libras, y eran
  # cuatro… se va a poder corregir, las mismas etiquetas… medir de nuevo"*.
  # Jorge, en staging: *"cuando un warehouse receipt ya tiene medidas y se
  # vuelve a escanear no me pregunta si quiero editarlo"*.
  test "escanear una caja ya medida ofrece medir de nuevo, y el bulto nuevo reemplaza al viejo" do
    segunda = caja("1ZREMEDIR000002")

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear_a_la_mesa(segunda, 2)
    teclear "6", "10", "12", "14"
    espiar_impresion
    send_keys :f10
    assert_selector "[data-medicion-target='banner']", wait: 5
    viejo = Bulto.last

    escanear(@paquete.tracking)
    assert_selector "dialog[open]", text: "Esta caja ya está medida", wait: 5
    within("dialog[open]") { click_on "Medir de nuevo" }

    assert_no_selector "dialog[open]", wait: 5
    # El bulto entero vuelve a la mesa, no solo la caja escaneada.
    assert_selector "[data-medicion-target='mesa'] li", count: 2, wait: 5
    assert_selector "[data-medicion-target='mesa'] li", text: segunda.numero_recepcion
    assert_equal "6", find("#medicion_peso").value, "los números viejos vienen puestos para corregirlos"
    assert_equal "medicion_peso", foco, "el foco va al peso: lo que sigue es corregir"
    assert_selector "[data-medicion-target='aviso']", text: "Midiendo de nuevo"

    fill_in "medicion_peso", with: "4"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", wait: 5
    assert_equal 1, Bulto.count, "el nuevo reemplaza al viejo"
    assert_nil Bulto.find_by(id: viejo.id)
    assert_equal 4.0, Bulto.last.peso.to_f
    assert_equal Bulto.last.id, @paquete.reload.bulto_id
    assert_equal Bulto.last.id, segunda.reload.bulto_id
  end

  # C27-14 · Yusef: *"este tiene un bloqueo ahorita que me tiene loco… hay que
  # poner una opción ahí"*.
  test "una caja que no pasó por el manifiesto avisa, se puede medir igual, y queda sellada" do
    suelta = caja("1ZFLUJO00000009", estado: "enviado_honduras")

    visit medicion_index_path
    escanear(suelta.tracking)

    assert_selector "dialog[open]", text: "Todavía no se recibió", wait: 5
    assert_selector "dialog[open]", text: "Se puede medir igual"

    within("dialog[open]") { click_on "Medirlo igual" }

    assert_selector "[data-medicion-target='mesa'] li", count: 1, wait: 5
    assert_selector "[data-medicion-target='mesa'] li", text: "SIN MANIFIESTO"

    teclear "20", "10", "12", "14"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", wait: 5
    suelta.reload
    assert_not_nil suelta.bulto_id
    assert_equal "MD", suelta.salto_manifiesto_por
    assert_equal "enviado_honduras", suelta.estado, "el estado del paquete no se toca"
  end

  test "lo que no se encuentra es un modal rojo grande: Enter lo cierra, Escape no" do
    visit medicion_index_path
    escanear("NOEXISTE123")

    assert_selector "dialog[open]", text: "No se encontró", wait: 5
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "No se encontró"

    page.driver.browser.action.send_keys(:enter).perform
    assert_no_selector "dialog[open]", wait: 5
    assert_equal "codigo_medicion", foco
  end

  # 2026-09-08 · Jorge, en staging: *"esta vista está confusa"*. La última caja
  # salía **cuatro veces** —en «Cómo ingresó Miami», en el cuadrito MIDIENDO, en
  # el encabezado del panel y en la mesa—. Ahora sale una, en la mesa.
  test "una caja en la mesa se ve UNA vez, y no queda ni grilla ni panel de Miami" do
    segunda = caja("1ZUNAVEZ0000002")

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear_a_la_mesa(segunda, 2)

    # Se cuentan **apariciones del código en el texto**, no nodos con ese texto
    # exacto: la primera versión de este test daba verde con el código repetido
    # dentro de una frase más larga (el encabezado decía «RSPS… · Juan · CER»).
    texto = find("[data-medicion-target='trabajo']").text(:all)
    [ @paquete, segunda ].each do |p|
      veces = texto.scan(p.numero_recepcion).size
      assert_equal 1, veces, "#{p.numero_recepcion} aparece #{veces} veces en la columna de trabajo"
    end
    assert_no_selector "[data-medicion-target='grilla']"
    assert_no_selector "[data-medicion-target='panelMiami']"
    assert_no_selector "[data-medicion-target='codigoCaja']"
    # El cliente, una sola vez: en el encabezado de la tanda.
    assert_selector "[data-medicion-target='tandaCliente']", text: "Juan"
    # Y nada de reimprimir mientras se arma: no hay qué.
    assert_no_selector "[data-medicion-target='banner']", visible: :visible
    assert_no_button "Reimprimir la etiqueta"
  end

  # El «×» de un volumen, como el de una caja en /etiquetar. Deshacer no es
  # elegir: el volumen lo armó él y lo puede tirar.
  test "el × de un volumen quita ESE volumen y renumera" do
    segunda = caja("1ZEQUIS00000002")
    tercera = caja("1ZEQUIS00000003")

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    teclear "10", "10", "10", "10"
    send_keys :f5
    escanear_a_la_mesa(segunda, 1)
    teclear "20", "10", "10", "10"
    send_keys :f5
    assert_selector "[data-medicion-target='listaVolumenes'] li", count: 2, wait: 5

    find("[data-medicion-target='listaVolumenes'] li:first-child button").click

    assert_selector "[data-medicion-target='listaVolumenes'] li", count: 1, wait: 5
    assert_selector "[data-medicion-target='listaVolumenes'] li", text: /Volumen 1/i
    assert_selector "[data-medicion-target='listaVolumenes'] li", text: "20 lb"
    assert_no_selector "[data-medicion-target='listaVolumenes'] li", text: "10 lb"

    escanear_a_la_mesa(tercera, 1)
    assert_selector "[data-medicion-target='mesaTitulo']", text: /Volumen 2 · 1 caja en la mesa/i
  end

  # C27-04 · La «Notificación» de la pizarra —*medir → notificación → buscar el
  # resto*— son **dibujitos**, no una frase: Jorge, con un envío partido en
  # diez, *"¿podemos hacer dibujitos, para que se mire mejor?"*. Un cuadrito por
  # caja, coloreado por estado, con quién midió (C27-12), y **sin nada que
  # tocar** (C27-02).
  test "los dibujitos del envío dicen cuáles están, cuáles faltan y quién midió, y no se tocan" do
    pa, otros = grupo_de_tres(@paquete)
    segunda = llego(otros.first)

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)

    assert_selector "[data-medicion-target='tandaCajas'] li", count: 3, wait: 5
    assert_selector "[data-medicion-target='tandaCajas'] li[data-en-mesa]", count: 1, text: "MESA"
    assert_selector "[data-medicion-target='tandaCajas'] li[data-estado='aqui']", count: 2
    assert_selector "[data-medicion-target='tandaCajas'] li[data-estado='esperada']", count: 1
    assert_selector "[data-medicion-target='tandaCajas'] li[title*='#{segunda.numero_recepcion}']", text: segunda.numero_recepcion.last(4)
    assert_no_selector "[data-medicion-target='tandaCajas'] button", visible: :all

    linea = find("[data-medicion-target='tandaConsolidado']")
    assert_includes linea.text, "Consolidando #{pa.numero_documento}"
    assert_includes linea.text, "en la mesa 1"
    assert_includes linea.text, "faltan 2"
    assert_not_includes linea.text, segunda.numero_recepcion, "los códigos van en los dibujitos, no en la frase"

    ausentes = find("[data-medicion-target='tandaAusentes']")
    assert_includes ausentes.text, "1ZFALTA000000002 (no ha llegado a Miami)"
    assert_not_includes ausentes.text, segunda.numero_recepcion, "la que está acá se ve en el dibujo, no se lista"

    teclear "20", "10", "12", "14"
    espiar_impresion
    send_keys :f10
    assert_selector "[data-medicion-target='banner']", wait: 5

    escanear_a_la_mesa(segunda, 1)
    assert_selector "[data-medicion-target='tandaCajas'] li[data-estado='medida']", text: "MD"
    assert_selector "[data-medicion-target='tandaConsolidado']", text: "medidas 1"
  end

  # «Facturar lo que hay» cambia de momento, no de sentido: medir nunca se
  # frena, y la excepción sale **después de guardar**, en el banner, solo si el
  # consolidado quedó incompleto. Antes era un botón rojo permanente al lado de
  # la grilla, con la mesa completa.
  test "guardar un consolidado incompleto ofrece «facturar lo que hay» en el banner, y el modal lista lo que falta" do
    grupo_de_tres(@paquete)

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    assert_no_button "Facturar lo que hay"

    teclear "20", "10", "12", "14"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", wait: 5
    assert_selector "[data-medicion-target='bannerFaltan']", text: "Faltan 2 cajas"
    assert_selector "[data-medicion-target='bannerFaltan']", text: "1ZFALTA000000001 (no ha llegado a Miami)"
    assert_equal 1, Bulto.count, "medir no se frenó por el grupo incompleto"

    click_on "Facturar lo que hay"

    assert_selector "dialog[open]", text: "Facturar lo que hay", wait: 5
    assert_selector "dialog[open]", text: "1ZFALTA000000001 · no ha llegado a Miami"
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "Se va a seguir sin estas cajas"

    click_on "Sí, facturar lo que hay"

    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='banner']", text: "Se pasa sin el grupo completo (MD)"
    assert_no_button "Facturar lo que hay"
    assert_equal "MD", PreAlerta.where.not(union_parcial_at: nil).last.union_parcial_por
  end

  test "un consolidado completo NO ofrece facturar lo que hay" do
    consolidada = caja("1ZCOMPLETO00002")
    pa = consolidado_con(@paquete)
    pa.pre_alerta_paquetes.create!(tracking: consolidada.tracking, descripcion: "Bulto",
                                   fecha: Date.current, paquete: consolidada)

    visit medicion_index_path
    escanear_a_la_mesa(@paquete, 1)
    escanear_a_la_mesa(consolidada, 2)
    assert_selector "[data-medicion-target='tandaConsolidado']", text: "en la mesa 2"

    teclear "20", "10", "12", "14"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", wait: 5
    assert_no_button "Facturar lo que hay"
    assert_no_selector "[data-medicion-target='bannerFaltan']", visible: :visible
  end

  # C26-17 · El panel de la derecha: lo que falta del manifiesto.
  test "el panel dice qué falta de este manifiesto, y solo el admin puede sacar una caja" do
    manifiesto = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ], sucursal_origen: sucursales(:miami),
                                    estado: "recibido", fecha_enviado: Time.zone.parse("2026-08-20"),
                                    fecha_aduana: Time.zone.parse("2026-08-28"))
    @paquete.update!(manifiesto: manifiesto)
    caja("1ZPANEL00000002").update!(manifiesto: manifiesto)

    visit medicion_index_path

    assert_selector "[data-medicion-target='manifiestoNumero']", text: manifiesto.numero, wait: 5
    assert_selector "[data-medicion-target='manifiestoFechas']", text: "Salió de Miami el 20/08/2026"
    assert_selector "[data-medicion-target='manifiestoConteo']", text: "Miami mandó 2 · medidos 0 · faltan 2"
    assert_selector "[data-medicion-target='pendientes'] li", count: 2
    # El operario de medición no saca nada de la lista.
    # Se mira si **se ve**, no si tiene la clase: la clase `hidden` no esconde un
    # `ButtonComponent`, y este test daba verde con el botón a la vista.
    assert_no_selector "[data-medicion-target='pendientes'] li button", visible: :visible

    # Y al medir una, el panel lo refleja sin recargar.
    escanear_a_la_mesa(@paquete, 1)
    teclear "9", "9", "9", "9"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='manifiestoConteo']", text: "medidos 1 · faltan 1", wait: 5
    assert_selector "[data-medicion-target='pendientes'] li", count: 1
  end

  test "el admin saca una caja de la lista con su motivo" do
    manifiesto = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ], sucursal_origen: sucursales(:miami),
                                    estado: "recibido", fecha_enviado: Time.zone.parse("2026-08-20"))
    @paquete.update!(manifiesto: manifiesto)
    users(:admin).update!(iniciales: "AD")
    ingresar(users(:admin))

    visit medicion_index_path
    assert_selector "[data-medicion-target='pendientes'] li", count: 1, wait: 5

    find("[data-medicion-target='pendientes'] li button").click

    assert_selector "dialog[open]", text: "Sacar de la lista", wait: 5
    choose "Perdido", allow_label_click: true
    fill_in "medicion_descarte_nota", with: "no apareció en la bodega"
    within("dialog[open]") { click_on "Sacar de la lista" }

    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='sinPendientes']", visible: true
    assert_equal "perdido", @paquete.reload.medicion_descartada_motivo
    assert_equal "en_aduana", @paquete.estado, "sacarla de la lista no le cambia el estado"
  end

  private

  def consolidado_con(paquete)
    pa = PreAlerta.create!(numero_documento: "PA-S#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                           titulo: "Consolidado de prueba", creado_por_tipo: "usuario",
                           creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: paquete.tracking, descripcion: "Bulto",
                                   fecha: Date.current, paquete: paquete)
    pa
  end

  def grupo_de_tres(paquete)
    pa = consolidado_con(paquete)
    otros = %w[1ZFALTA000000001 1ZFALTA000000002].map do |t|
      pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Gorra", fecha: Date.current).paquete
    end
    [ pa, otros ]
  end

  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami),
                    tipo_envio: tipo_envios(:cer))
    paquete.update!(estado: "en_aduana")
    paquete.reload
  end
end
