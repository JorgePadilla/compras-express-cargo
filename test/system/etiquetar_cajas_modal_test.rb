require "application_system_test_case"

# PR-C6.18b: peso y medidas de cada caja, **en el formulario**.
#
# La primera versión (PR-C6.17) puso esto adentro del modal de F9, porque ahí
# era donde se preguntaba la cantidad de cajas. Jorge lo probó y fue directo al
# punto: **"el F9 era como confuso"**.
#
# Tenía razón, y el motivo se ve al mirar la pantalla: el formulario mostraba
# "Cant. Productos" —que es cuántos artículos vienen adentro— y parecía el
# campo que mandaba, mientras el que de verdad divide el tracking en bultos
# estaba escondido detrás de una tecla.
#
# Ahora la cantidad de cajas vive junto al peso y las medidas, que es donde
# Yusef la señaló: "acá sería cantidad de paquetes o productos, y aquí el peso
# de cada quien". F9 vuelve a ser solo guardar e imprimir.
#
# Va como system test porque las filas las pinta el JS: ningún test de
# integración puede ver que aparezcan.
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

  test "la cantidad de cajas esta a la vista, no detras de F9" do
    assert_selector "#paquete_cantidad_paquetes"
    assert_text "Cant. Cajas"
  end

  test "F9 ya no pregunta cuantas cajas" do
    # Era el paso que confundía. Ahora guarda e imprime directo.
    assert_no_selector "#cajas-input", visible: :all
  end

  test "con una sola caja no pide peso por caja" do
    # El formulario ya lo preguntó; repetirlo sería un paso de más.
    assert_no_selector "[name='paquete[cajas][1][peso]']"
  end

  test "con dos cajas aparecen dos filas de peso y medidas" do
    poner_cajas(2)

    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3
    assert_selector "[name='paquete[cajas][2][peso]']"
    assert_selector "[name='paquete[cajas][2][alto]']"
    assert_no_selector "[name='paquete[cajas][3][peso]']"
  end

  test "las filas se precargan con lo del formulario" do
    # Si las cajas son parecidas basta con Enter: solo se tocan las que
    # difieren.
    find("#paquete_peso").set("7.5")
    find("#paquete_alto").set("12")
    poner_cajas(2)

    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3
    assert_equal "7.5", find("[name='paquete[cajas][2][peso]']").value
    assert_equal "12",  find("[name='paquete[cajas][2][alto]']").value
  end

  test "cambiar la cantidad repinta las filas" do
    poner_cajas(3)
    assert_selector "[name='paquete[cajas][3][peso]']", wait: 3

    poner_cajas(2)
    assert_no_selector "[name='paquete[cajas][3][peso]']", wait: 3
    assert_selector "[name='paquete[cajas][2][peso]']"
  end

  test "volver a una sola caja esconde las filas" do
    poner_cajas(2)
    assert_selector "[name='paquete[cajas][1][peso]']", wait: 3

    poner_cajas(1)
    assert_no_selector "[name='paquete[cajas][1][peso]']", wait: 3
  end

  test "Cant. Productos y Cant. Cajas son campos distintos" do
    # La confusión que originó todo esto: productos es el contenido, cajas son
    # los bultos físicos. Poner 2 productos no divide nada.
    find("#paquete_cantidad_productos").set("2")

    assert_no_selector "[name='paquete[cajas][1][peso]']", wait: 2
  end

  private

  def poner_cajas(n)
    find("#paquete_cantidad_paquetes").set(n.to_s)
  end
end
