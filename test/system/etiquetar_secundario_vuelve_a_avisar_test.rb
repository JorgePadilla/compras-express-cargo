require "application_system_test_case"

# C16-05: el secundario pre-alertado a nombre de otro vuelve a avisar.
#
# Yusef, 2026-08-25: metió un paquete cuyo secundario estaba pre-alertado a
# nombre de otra clienta —avisó—, le dio «Dejarlo de lado y seguir», metió otro
# paquete con **el mismo** secundario, y:
#
#   "No, pero aquí lo puse a nombre de alguien más. No lo detectó, mirá."
#   "Es el mismo tracking, lo agarré, lo volví a usar… ya lo había detectado,
#    y se quedó esto así, mirá: no lo limpió."
#
# Dos causas. «Dejarlo de lado» limpia sin recargar, y la memoria que evita
# consultar dos veces el mismo secundario no se reiniciaba: el segundo paquete
# ni consultaba. Y el secundario está arriba del cliente en el formulario, así
# que en el orden natural se revisa con el cliente vacío — la primera vez avisó
# solo porque la pre-alerta del primario ya había puesto al cliente.
#
# Va como system test porque las dos causas viven en el estado del JS.
class EtiquetarSecundarioVuelveAAvisarTest < ApplicationSystemTestCase
  # Pre-alertado por María en CER —la misma sesión que se abre abajo, para que
  # el único aviso posible sea el del cliente—; los paquetes se meten a nombre
  # de Juan (CEC-001).
  SECUNDARIO_DE_MARIA = "1ZDEMARIA0000001"

  setup do
    pa = PreAlerta.create!(cliente: clientes(:maria), tipo_envio: tipo_envios(:cer),
                           titulo: "Lo de María", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: SECUNDARIO_DE_MARIA, descripcion: "Cosméticos")

    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "despues de «dejarlo de lado», el mismo secundario vuelve a avisar" do
    meter_paquete_de_juan_con_el_secundario_de_maria("1ZPRIMERO0000001")
    assert_aviso_de_otro_cliente

    find("[data-etiquetar-target=conflictoSesionDejarBtn]").click
    assert_no_selector "[data-etiquetar-target=conflictoSesionModal]:not(.hidden)", wait: 5

    meter_paquete_de_juan_con_el_secundario_de_maria("1ZSEGUNDO0000001")
    assert_aviso_de_otro_cliente
  end

  test "despues de F2 tambien" do
    meter_paquete_de_juan_con_el_secundario_de_maria("1ZPRIMERO0000002")
    assert_aviso_de_otro_cliente

    find("[data-etiquetar-target=conflictoSesionDejarBtn]").click
    page.send_keys(:f2)

    meter_paquete_de_juan_con_el_secundario_de_maria("1ZSEGUNDO0000002")
    assert_aviso_de_otro_cliente
  end

  test "avisa aunque el cliente se elija despues del secundario" do
    # El orden natural del formulario: el secundario está arriba del cliente.
    campo("paquete_tracking").send_keys("1ZPRIMERO0000003", :enter)
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(SECUNDARIO_DE_MARIA, :enter)
    esperar_la_respuesta_del_secundario
    # Sin cliente no hay contra qué comparar todavía.
    assert_no_selector "[data-etiquetar-target=conflictoSesionModal]:not(.hidden)"

    elegir_cliente("1")

    assert_aviso_de_otro_cliente
  end

  test "si el cliente es el mismo de la pre-alerta, no avisa" do
    campo("paquete_tracking").send_keys("1ZPRIMERO0000004", :enter)
    elegir_cliente("2")
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(SECUNDARIO_DE_MARIA, :enter)

    esperar_la_respuesta_del_secundario
    assert_no_selector "[data-etiquetar-target=conflictoSesionModal]:not(.hidden)"
  end

  private

  def meter_paquete_de_juan_con_el_secundario_de_maria(tracking)
    campo("paquete_tracking").send_keys(tracking, :enter)
    elegir_cliente("1")
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(SECUNDARIO_DE_MARIA, :enter)
  end

  def elegir_cliente(codigo)
    cliente = find("[data-etiquetar-target=clienteInput]")
    cliente.send_keys(codigo)
    assert_selector "[data-index]", wait: 5
    cliente.send_keys(:enter)
    assert page.evaluate_script("document.querySelector('[data-etiquetar-target=clienteId]').value") != "",
           "no se eligió ningún cliente"
  end

  # El servidor contestó por el secundario: `_revisarSecundarioConPreAlerta`
  # dispara `preAlertaMatch` apenas llega la respuesta, antes de comparar.
  def esperar_la_respuesta_del_secundario
    Timeout.timeout(5) { sleep 0.1 until page.evaluate_script("window.__preAlertaMatch === true") }
  rescue Timeout::Error
    flunk "el secundario nunca se consultó"
  end

  def assert_aviso_de_otro_cliente
    assert_selector "[data-etiquetar-target=conflictoSesionModal]:not(.hidden)", wait: 5
    assert_text "a nombre de otro cliente"
  end

  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5
  end

  def abrir_etiquetar
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      find("button[name='tipo_envio_id'][value='#{tipo_envios(:cer).id}']").click
    end
    assert_selector "#paquete_tracking", wait: 5
    page.execute_script(<<~JS)
      window.__preAlertaMatch = false
      document.addEventListener("etiquetar:preAlertaMatch", function () { window.__preAlertaMatch = true })
    JS
  end

  def campo(id) = find("##{id}")
end
