require "application_system_test_case"

# PR-C30.8 · El bug que C30-10 encontró en la PESA, en las otras pantallas de
# escaneo.
#
# Yusef, en la PESA: *"la nota del cliente, al darle entendido acá, no
# regresas"*. Cerrar un modal **con el dedo o el mouse** dejaba el campo de
# escaneo con cara de enfocado —`document.activeElement` decía que era él—,
# pero lo que tecleaba la pistola no entraba: el clic deja la selección del
# documento afuera, y el teclado escribe donde está la selección.
#
# Los tests de estas pantallas cerraban los modales con Enter, que no tiene
# el problema, y miraban `activeElement`, que mentía. Acá se cierra con
# `click_on` y la prueba es que **lo que se teclea después entre**: se teclea
# con el teclado de la página (`action.send_keys`), no sobre un elemento,
# porque `find(…).send_keys` lo enfoca primero y tapa el bug.
class FocoTrasModalEnLasGemelasTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
  end

  def teclear(texto) = page.driver.browser.action.send_keys(texto).perform

  # El foco vuelve un frame después de cerrarse el modal (`requestAnimationFrame`
  # en /empacar y /etiquetar): la pistola de verdad no le gana a un frame, el
  # teclado de Selenium sí.
  def esperar_un_frame
    page.evaluate_async_script("requestAnimationFrame(() => requestAnimationFrame(arguments[0]))")
  end

  def paquete(tracking, tipo:)
    Paquete.create!(tracking: tracking, cliente: clientes(:juan), tipo_envio: tipo,
                    estado: "recibido_miami", sucursal: sucursales(:zeron_sps),
                    sucursal_recepcion: sucursales(:miami), peso: 3)
  end

  test "manifiesto: «Entendido» con el mouse y la pistola sigue escaneando" do
    manifiesto = manifiestos(:creado)
    manifiesto.update!(sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:cer) ])
    cem = paquete("1ZGEMELACEM0001", tipo: tipo_envios(:cem))
    bueno = paquete("1ZGEMELACER0001", tipo: tipo_envios(:cer))

    visit manifiesto_path(manifiesto)
    find("#buscar_paquete").send_keys(cem.numero_recepcion, :enter)
    assert_selector "dialog[open]", text: "Tipo de envío distinto", wait: 5
    within("dialog[open]") { click_on "Entendido" }
    assert_no_selector "dialog[open]", wait: 5
    esperar_un_frame

    teclear(bueno.numero_recepcion)
    assert_equal bueno.numero_recepcion, find("#buscar_paquete").value, "la pistola escribió en el aire"
    teclear(:enter)
    within("#manifiesto-paquetes") { assert_text bueno.tracking, wait: 5 }
    assert_equal manifiesto, bueno.reload.manifiesto
  end

  test "empacar: «Entendido» con el dedo y la pistola sigue escaneando" do
    manifiesto = manifiestos(:creado)
    manifiesto.update!(sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:express) ])
    caja = manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    ajeno = paquete("1ZGEMELAAJENO01", tipo: tipo_envios(:cer))
    bueno = paquete("1ZGEMELABUENO01", tipo: tipo_envios(:express))

    visit manifiesto_empacar_path(manifiesto)
    find("#codigo_empaque").send_keys(ajeno.numero_recepcion, :enter)
    assert_selector "dialog[open]", text: "Tipo de envío distinto", wait: 5
    within("dialog[open]") { click_on "Entendido" }
    assert_no_selector "dialog[open]", wait: 5
    esperar_un_frame

    teclear(bueno.numero_recepcion)
    assert_equal bueno.numero_recepcion, find("#codigo_empaque").value, "la pistola escribió en el aire"
    teclear(:enter)
    assert_text "entró a la caja", wait: 5
    assert_equal caja.id, bueno.reload.caja_manifiesto_id
  end

  test "etiquetar: cerrar el aviso de la bolsa con el mouse y el tracking recibe la pistola" do
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    page.execute_script(<<~JS)
      const ctrl = window.Stimulus.getControllerForElementAndIdentifier(
        document.querySelector("[data-controller~='etiquetar']"), "etiquetar")
      ctrl._sucursalActual = "SAN PEDRO SULA"
      ctrl._avisarLaBolsa = true
      ctrl._avisarSucursalAlFinal()
    JS
    assert_selector "dialog[data-etiquetar-target='sucursalModal'][open]", wait: 5
    find("dialog[data-etiquetar-target='sucursalModal'] button").click
    assert_no_selector "dialog[open]", wait: 5
    esperar_un_frame

    # Sin Enter: lo que se prueba es dónde cae lo que se teclea. Enter acá
    # avanza de campo (nunca guarda) y saldría a buscar el tracking.
    teclear("1ZGEMELATRK0001")
    assert_equal "1ZGEMELATRK0001", find("#paquete_tracking").value, "la pistola escribió en el aire"
  end

  test "etiquetar: contestar un aviso con el mouse deja seguir tecleando en el campo donde estaba" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo),
                           estado: "pre_alerta", titulo: "Retenida anunciada")
    pa.pre_alerta_paquetes.create!(tracking: "1ZGEMELAAVISO01", descripcion: "Perfumes", retener_miami: true)

    abrir_sesion_etiquetar(tipo_envios(:aereo))
    find("#paquete_tracking").send_keys("1ZGEMELAAVISO01", :enter)
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", text: "NO DESPACHAR", wait: 5
    click_on "Retenido, confirmado"
    assert_no_selector "dialog[open]", wait: 5

    # El navegador devuelve el foco al campo que lo tenía antes del aviso —acá,
    # el del cliente, adonde pasó el Enter de la pistola—; lo que importa es
    # que lo que se teclee entre ahí y no se pierda.
    esperar_un_frame
    assert_equal "INPUT", page.evaluate_script("document.activeElement.tagName"), "el foco no quedó en ningún campo"
    antes = page.evaluate_script("document.activeElement.value").to_s
    teclear("7")
    assert_equal "#{antes}7", page.evaluate_script("document.activeElement.value").to_s, "lo tecleado no entró"
    assert_equal "pre_alerta_estado", Paquete.find_by!(tracking: "1ZGEMELAAVISO01").estado,
                 "contestar el aviso no guarda nada"
  end
end
