require "application_system_test_case"

# C22-02 · Yusef, 2026-08-31, en la misma llamada del bug de limpiar:
#
#   "¿Sabés qué deberíamos crear? Tal vez **una función para finalizar** […]
#    una función, un F. **Tal vez F11** o algo así, no sé si lo tenés ya
#    agarrado."
#   "Ya que le vas a hacer un cambio, si podés ponerle un F11."
#
# La tecla dispara el botón que ya existe en vez de pegarle al endpoint, y por
# eso hereda su confirmación — decisión de Jorge: un roce de tecla no puede
# dejar al operario sin sesión, porque el siguiente paquete se recibiría con
# otro tipo de envío.
#
# **Lo que este test NO puede probar:** si Chrome le cede F11 a la página o se
# la queda para pantalla completa. En headless no hay pantalla completa que
# robar, así que esto pasa igual con la tecla peleada. Eso se verifica a mano en
# un Chrome de verdad.
class EtiquetarF11FinalizaSesionTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end

  test "F11 finaliza la sesión, pasando por la confirmación" do
    assert_button BOTON_FINALIZAR_SESION

    # Mismas tres formas del confirm que documenta `cerrar_sesion_etiquetar_si_hay_una`.
    begin
      accept_confirm { find("body").send_keys(:f11) }
    rescue Capybara::ModalNotFound
      within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
    end

    assert_text "¿Qué tipo de envío vas a trabajar?", wait: 5
  end

  # El otro lado: la confirmación tiene que poder decir que no. Si F11 finalizara
  # derecho, un roce de tecla dejaría al operario eligiendo tipo de envío en
  # medio de un lote.
  test "cancelar la confirmación deja la sesión abierta" do
    begin
      dismiss_confirm { find("body").send_keys(:f11) }
    rescue Capybara::ModalNotFound
      within(MODAL_CONFIRMAR) { click_on "Cancelar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
    end

    assert_button BOTON_FINALIZAR_SESION, wait: 5
    assert_no_text "¿Qué tipo de envío vas a trabajar?"
  end
end
