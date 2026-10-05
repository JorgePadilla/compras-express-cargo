require "application_system_test_case"

# C28-04 · El escaneo del manifiesto dice por qué, y siempre limpia.
#
# Yusef, 2026-10-03: *"cuando hay un error, siempre hay que limpiarlo"*. Y
# para el paquete que está en otro manifiesto: *"ahí es un modal: ¿desea
# agregar este a este manifiesto y retirarlo del otro?"*.
#
# Lo que se prueba acá no se ve en el JSON: que el `<dialog>` abra, que Enter
# apriete el botón que importa, y que el foco vuelva a la pistola.
class ManifiestoEscaneoModalTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:cer) ])
  end

  test "en otro manifiesto abierto: el modal ofrece moverlo, y Enter lo mueve" do
    otro = Manifiesto.create!(numero: "MA-OTRO-SYS1", estado: "creado", user: users(:digitador),
                              sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:cer) ])
    viajero = paquete("1ZMOVER0000001")
    viajero.update!(manifiesto: otro)

    visit manifiesto_path(@manifiesto)
    find("#buscar_paquete").send_keys(viajero.numero_recepcion, :enter)

    assert_selector "dialog[open]", text: "Está en otro manifiesto", wait: 5
    assert_selector "dialog[open]", text: otro.numero
    assert_equal "", find("#buscar_paquete", visible: :all).value, "el campo se limpia aunque haya error"

    page.driver.browser.action.send_keys(:enter).perform

    assert_no_selector "dialog[open]", wait: 5
    within("#manifiesto-paquetes") { assert_text viajero.tracking, wait: 5 }
    assert_equal @manifiesto, viajero.reload.manifiesto
    assert_equal "buscar_paquete", page.evaluate_script("document.activeElement.id")
  end

  test "de otro servicio: modal rojo sin mover, Enter lo cierra y el foco vuelve" do
    cem = paquete("1ZCEM00000001", tipo: tipo_envios(:cem))

    visit manifiesto_path(@manifiesto)
    find("#buscar_paquete").send_keys(cem.numero_recepcion, :enter)

    assert_selector "dialog[open]", text: "Tipo de envío distinto", wait: 5
    assert_no_selector "dialog[open] button", text: "Moverlo a este manifiesto"

    page.driver.browser.action.send_keys(:enter).perform

    assert_no_selector "dialog[open]", wait: 5
    assert_nil cem.reload.manifiesto_id
    assert_equal "buscar_paquete", page.evaluate_script("document.activeElement.id")
  end

  # *"No es error grave, es error de dedo"*: aviso, no modal.
  test "el que ya está en este manifiesto avisa sin modal" do
    adentro = paquete("1ZADENTRO00001")
    adentro.update!(manifiesto: @manifiesto)

    visit manifiesto_path(@manifiesto)
    find("#buscar_paquete").send_keys(adentro.numero_recepcion, :enter)

    assert_text "ya fue escaneado y está en este manifiesto", wait: 5
    assert_no_selector "dialog[open]"
    assert_equal "", find("#buscar_paquete").value
  end

  private

  def paquete(tracking, tipo: tipo_envios(:cer))
    Paquete.create!(tracking: tracking, cliente: clientes(:juan), tipo_envio: tipo,
                    estado: "recibido_miami", sucursal: sucursales(:zeron_sps),
                    sucursal_recepcion: sucursales(:miami), peso: 3)
  end
end
