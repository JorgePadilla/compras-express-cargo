require "application_system_test_case"

# PR-C6.23: el botón "Cambio de servicio" del modal de duplicado no saca a
# nadie de /etiquetar.
#
# Yusef, 2026-08-08:
#
#   "Cambio de servicio **envía donde no es**."
#   "Si yo presiono cambio de servicio, **me tire aquí de un solo a esto**."
#   "Es que ellos no manejan la página de paquetes."
#
# Va como system test porque el bug vive entero en el navegador: es un
# `window.location.href` dentro del handler del botón.
class EtiquetarCambioServicioTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @existente = paquetes(:recibido)
    abrir_etiquetar
  end

  test "cambio de servicio se queda en etiquetar y abre el modal del destino" do
    escanear_un_tracking_repetido

    click_on "Cambio de Servicio"

    assert_current_path(/\/etiquetar/, ignore_query: false, wait: 5)
    assert_selector "dialog[data-checkbox-modal-target=dialog][open]", wait: 5
    assert_selector "select[name='paquete[tipo_envio_destino_id]']", visible: :all
  end

  test "el paquete que se estaba escaneando queda cargado" do
    # No alcanza con llegar a /etiquetar: tiene que llegar CON el paquete, o
    # el operario vuelve a teclear todo.
    escanear_un_tracking_repetido

    click_on "Cambio de Servicio"
    assert_selector "dialog[data-checkbox-modal-target=dialog][open]", wait: 5

    assert_equal @existente.tracking, find("#paquete_tracking").value
    assert find("#paquete_solicito_cambio_servicio").checked?,
           "llegó sin el check marcado: es el clic de más que Yusef estaba contando"
  end

  test "marcar el check a mano sigue abriendo el modal al instante" do
    # Esta mitad ya funcionaba y no se tocó — el `<dialog>` viene renderizado
    # en la página, así que no hay ida al servidor. Queda fijado para que el
    # arreglo de arriba no se la lleve puesta.
    assert_no_selector "dialog[data-checkbox-modal-target=dialog][open]"

    find("#paquete_solicito_cambio_servicio").click

    assert_selector "dialog[data-checkbox-modal-target=dialog][open]", wait: 3
  end

  private

  # El modal de duplicado sale solo al escanear un tracking que ya existe.
  def escanear_un_tracking_repetido
    find("#paquete_tracking").send_keys(@existente.tracking, :enter)
    assert_selector "[data-etiquetar-target=duplicateModal]:not(.hidden)", wait: 5
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
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end
end
