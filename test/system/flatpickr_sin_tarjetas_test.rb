require "application_system_test_case"

# PR: que Chrome deje de ofrecer tarjetas de crédito en los campos de fecha.
#
# Jorge: *"salen las tarjetas de crédito, como que el campo es de tarjeta pero
# es fecha, ¿por qué?"*.
#
# Por `altInput: true`: flatpickr esconde el input real —el del `name`— y crea
# **otro de texto, visible, sin name y sin autocomplete**. Chrome ve un campo
# anónimo que muestra `17/08/2026` y lo clasifica de oído como vencimiento de
# tarjeta.
#
# ⚠️ El menú de autofill es **cromo del navegador, no DOM**: ningún test puede
# afirmar que dejó de salir. Lo que se fija acá son los atributos que se lo
# impiden; que la lista desaparezca se comprueba mirando.
#
# Va como system test porque ese input **no existe en el HTML del servidor** —
# lo crea el JS al montar. Y CI no corre `test/system`, así que esto es una red
# para cuando se pide a mano.
class FlatpickrSinTarjetasTest < ApplicationSystemTestCase
  setup { ingresar(users(:digitador)) }

  test "el campo visible que crea flatpickr no se ofrece al autofill" do
    visit new_pre_alerta_path
    assert_selector "input.flatpickr-input", wait: 5, visible: :all

    alt = find("input.form-control.input", match: :first, visible: :all)

    assert_equal "off", alt[:autocomplete]
    assert_equal "true", alt["data-1p-ignore"]
    assert_equal "true", alt["data-lpignore"]
    assert_equal "other", alt["data-form-type"]
  end

  test "vale para todas las fechas, no solo la de la pre-alerta" do
    # El arreglo vive en el controller de flatpickr, así que las seis fechas de
    # la app quedan cubiertas. Se prueba en otra pantalla para fijarlo.
    visit paquetes_path
    assert_selector "input.flatpickr-input", wait: 5, visible: :all

    sin_proteger = page.all("input.flatpickr-input", visible: :all).count do |input|
      # El input REAL de flatpickr queda oculto y no le pide nada al autofill;
      # el que importa es el visible, que es el `altInput`.
      input.visible? && input[:autocomplete] != "off"
    end

    assert_equal 0, sin_proteger, "quedó una fecha visible sin `autocomplete=off`"
  end

  private

  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8
  end
end
