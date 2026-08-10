require "application_system_test_case"

# PR-C6.41 · RP-04b: al elegir un cliente que paga SOLO volumétrico en este
# servicio, el panel de cálculo tiene que mostrar el volumétrico como peso a
# cobrar — no el de la báscula.
#
# No es cosmético. Si la pantalla dice 30 lb y la pre-factura cobra 4, el
# operario no tiene forma de saber cuál de los dos está mal. Es el mismo defecto
# que PR-10.a vino a cerrar: la calculadora de /etiquetar mostrando un peso y la
# factura cobrando otro.
class EtiquetarCobroVolumetricoTest < ApplicationSystemTestCase
  setup do
    @cliente = clientes(:maria)
    @cer = tipo_envios(:cer)

    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5
  end

  test "con el trato puesto manda el volumetrico aunque el peso sea mayor" do
    @cliente.tipo_envio_solo_volumetricos << @cer

    abrir_sesion_cer
    elegir_cliente
    medir(peso: 30, alto: 8, largo: 9, ancho: 9)  # 648 pulg3 → 4.0 VLbs

    assert_selector "[data-calc-volumetrico-target=pesoCobrar]", text: "4.00", wait: 5
    assert_text "solo el volumetrico en este servicio"
  end

  test "sin el trato sigue mandando el peso de la bascula" do
    abrir_sesion_cer
    elegir_cliente
    medir(peso: 30, alto: 8, largo: 9, ancho: 9)

    assert_selector "[data-calc-volumetrico-target=pesoCobrar]", text: "30.00", wait: 5
    assert_no_text "solo el volumetrico en este servicio"
  end

  test "el trato es por servicio: en otro no aplica" do
    # El mismo mayorista, con el trato en CEM, trabajado en una sesion de CER.
    @cliente.tipo_envio_solo_volumetricos << tipo_envios(:cem)

    abrir_sesion_cer
    elegir_cliente
    medir(peso: 30, alto: 8, largo: 9, ancho: 9)

    assert_selector "[data-calc-volumetrico-target=pesoCobrar]", text: "30.00", wait: 5
  end

  test "sin medidas se sigue viendo el peso real, nunca cero" do
    # El unico camino por el que esta feature podria regalar flete.
    @cliente.tipo_envio_solo_volumetricos << @cer

    abrir_sesion_cer
    elegir_cliente
    medir(peso: 30)

    assert_selector "[data-calc-volumetrico-target=pesoCobrar]", text: "30.00", wait: 5
  end

  private

  def abrir_sesion_cer
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      find("button[name='tipo_envio_id'][value='#{@cer.id}']").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  def elegir_cliente
    campo = find("[data-etiquetar-target=clienteInput]")
    campo.click
    campo.send_keys(@cliente.codigo)
    assert_selector "[data-index]", wait: 5
    campo.send_keys(:enter)
  end

  def medir(peso:, alto: nil, largo: nil, ancho: nil)
    fill_in "paquete[peso]", with: peso
    return if alto.nil?

    fill_in "paquete[alto]",  with: alto
    fill_in "paquete[largo]", with: largo
    fill_in "paquete[ancho]", with: ancho
  end
end
