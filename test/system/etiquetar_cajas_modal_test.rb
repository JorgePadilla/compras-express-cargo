require "application_system_test_case"

# PR-C6.17: el modal de F9 pide peso y medidas de cada caja.
#
# Jorge probándolo: "cuando son 2 productos, ¿cómo le pongo los valores a la
# otra caja? Solo tengo opción para 1".
#
# Va como system test porque las filas las pinta el JS al cambiar la cantidad:
# ningún test de integración puede ver que aparezcan.
class EtiquetarCajasModalTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5

    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  test "con una sola caja no pregunta peso por caja" do
    # El formulario ya lo preguntó; repetirlo sería un paso de más.
    abrir_modal
    assert_no_selector "[name='paquete[cajas][1][peso]']"
  end

  test "con dos cajas aparecen dos filas de peso y medidas" do
    abrir_modal
    poner_cantidad(2)

    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3
    assert_selector "[name='paquete[cajas][2][peso]']"
    assert_selector "[name='paquete[cajas][2][alto]']"
    assert_no_selector "[name='paquete[cajas][3][peso]']"
  end

  test "las filas se precargan con lo del formulario" do
    # Si las cajas son parecidas basta con Enter: el operario solo toca las
    # que difieren.
    find("#paquete_peso").set("7.5")
    find("#paquete_alto").set("12")
    abrir_modal
    poner_cantidad(2)

    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3
    assert_equal "7.5", find("[name='paquete[cajas][2][peso]']").value
    assert_equal "12",  find("[name='paquete[cajas][2][alto]']").value
  end

  test "cambiar la cantidad repinta las filas" do
    abrir_modal
    poner_cantidad(3)
    assert_selector "[name='paquete[cajas][3][peso]']", wait: 3

    poner_cantidad(2)
    assert_no_selector "[name='paquete[cajas][3][peso]']", wait: 3
    assert_selector "[name='paquete[cajas][2][peso]']"
  end

  test "volver a una sola caja esconde las filas" do
    abrir_modal
    poner_cantidad(2)
    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3

    poner_cantidad(1)
    assert_no_selector "[name='paquete[cajas][1][peso]']", wait: 3
  end

  private

  def abrir_modal
    find("#paquete_tracking").set("1Z999CAJAS#{SecureRandom.hex(2)}")
    page.send_keys(:f9)
    assert_selector "#cajas-input", visible: :all, wait: 5
  end

  def poner_cantidad(n)
    find("#cajas-input", visible: :all).set(n.to_s)
  end
end
