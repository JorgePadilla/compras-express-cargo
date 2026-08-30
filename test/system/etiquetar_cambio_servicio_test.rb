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
    # Un recibido SIN pre-alerta, a propósito. El fixture `recibido` está
    # vinculado a `PA-000002`, y un pre-alertado ya recibido no entra al modal
    # de duplicado: el escaneo lo resuelve como pre-alerta encontrada (`C20-09`,
    # diferido). Este test es del botón del modal de duplicado, no de eso.
    @existente = crear_recibido
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


  # La sesión se abre en el tipo de envío del paquete que se va a escanear.
  # Desde `PR-C7.62` los modales salen de a uno y **el conflicto de sesión
  # manda**: con la sesión en otro tipo, lo que sale es «este paquete es de
  # otro tipo de envío», nunca el de duplicado — y este test se quedaba
  # esperándolo.
  def abrir_etiquetar
    abrir_sesion_etiquetar(TipoEnvio.find(@existente.tipo_envio_id))
  end

  def crear_recibido
    Paquete.create!(
      tracking: "1Z999CAMBIO#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
      estado: "recibido_miami", descripcion: "Perfumes", user: users(:digitador)
    )
  end
end
