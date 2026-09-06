require "application_system_test_case"

# C25-09 · El error de escaneo en /empacar es un modal.
#
# Yusef: *"ese debería ser un modal, sí, siempre… el modal más que todo cuando
# hay error, hay alertas"*. Y el porqué: *"la compu está allá y ellos están
# acá"* — un aviso en la pantalla no lo ve nadie desde la mesa.
#
# Lo que importa acá no se ve en el HTML: que el `<dialog>` **abra**, que Enter
# lo cierre, y que **el foco vuelva al campo** para el escaneo siguiente. Eso
# lo decide el navegador, así que se prueba en Chrome de verdad.
class EmpaqueAvisoModalTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami), tipo_envios: [ tipo_envios(:express) ])
    @caja = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
  end

  test "un tipo de envío distinto abre el modal, Enter lo cierra y el foco vuelve al campo" do
    ajeno = paquete(tracking: "1ZAJENO000001", tipo: tipo_envios(:cer))

    visit manifiesto_empacar_path(@manifiesto)
    find("#codigo_empaque").send_keys(ajeno.numero_recepcion, :enter)

    assert_selector "dialog[open]", wait: 5
    assert_selector "dialog[open]", text: "Tipo de envío distinto"
    assert_selector "dialog[open] button", text: "Meterlo igual", visible: true

    page.driver.browser.action.send_keys(:enter).perform

    assert_no_selector "dialog[open]", wait: 5
    assert_equal "codigo_empaque", page.evaluate_script("document.activeElement.id"),
                 "después del modal, la pistola tiene que poder seguir"
    assert_nil ajeno.reload.caja_manifiesto_id, "«Entendido» no lo mete"
  end

  test "«Meterlo igual» desde el modal lo empaca y cierra" do
    ajeno = paquete(tracking: "1ZAJENO000002", tipo: tipo_envios(:cer))

    visit manifiesto_empacar_path(@manifiesto)
    find("#codigo_empaque").send_keys(ajeno.numero_recepcion, :enter)
    assert_selector "dialog[open]", wait: 5

    within("dialog[open]") { click_on "Meterlo igual (omitir)" }

    assert_no_selector "dialog[open]", wait: 5
    assert_equal @caja.id, ajeno.reload.caja_manifiesto_id
    assert_equal "codigo_empaque", page.evaluate_script("document.activeElement.id")
  end

  # *"Cuando está bien, ¿que diga que sí? No, no, no."*
  test "un escaneo bueno no abre ningún modal" do
    bueno = paquete(tracking: "1ZBUENO000001", tipo: tipo_envios(:express))

    visit manifiesto_empacar_path(@manifiesto)
    find("#codigo_empaque").send_keys(bueno.numero_recepcion, :enter)

    assert_text "entró a la caja", wait: 5
    assert_no_selector "dialog[open]"
    assert_equal @caja.id, bueno.reload.caja_manifiesto_id
  end

  # Escape no contesta un aviso (`C20-13`): *"ellos no las leen"*.
  test "Escape no cierra el modal" do
    ajeno = paquete(tracking: "1ZAJENO000003", tipo: tipo_envios(:cer))

    visit manifiesto_empacar_path(@manifiesto)
    find("#codigo_empaque").send_keys(ajeno.numero_recepcion, :enter)
    assert_selector "dialog[open]", wait: 5

    page.driver.browser.action.send_keys(:escape).perform

    assert_selector "dialog[open]"
  end

  private

  def paquete(tracking:, tipo:)
    Paquete.create!(tracking: tracking, cliente: clientes(:juan), tipo_envio: tipo,
                    estado: "recibido_miami", sucursal: sucursales(:zeron_sps),
                    sucursal_recepcion: sucursales(:miami), peso: 3)
  end
end
