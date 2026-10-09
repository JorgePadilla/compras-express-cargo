require "application_system_test_case"

# C16-02: el pito de «podés seguir».
#
# Yusef, 2026-08-25, con la pistola en la mano:
#
#   "¿Cuándo escuchás el pip? Cuando el sistema buscó en los paquetes y vio
#    que no existía."
#   "Cuando yo presiono tres, acá, él debe pitar para que yo presione Enter."
#   "Siempre hay pitos para decir: ok, podés seguir."
#
# Jorge, mirándolo: "ay, no está pitando". El pin de guardado existía desde
# abril y sonaba solo al grabar; el chequeo que vuelve limpio y el cliente que
# aparece abrían mudos, con `A1-10` marcándolos ✅.
#
# Va como system test porque los eventos los dispara el JS al resolverse el
# `fetch`: sin navegador no hay nada que oír. Se escucha el evento de Stimulus
# —el que la vista cablea a `audio#success`— y no el sonido, que WebAudio no
# emite sin gesto del usuario.
class EtiquetarPitoPodesSeguirTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
    escuchar("etiquetar:trackingLibre", "etiquetar:clienteEncontrado", "etiquetar:preAlertaMatch")
  end

  test "un tracking que no esta en ningun lado pita al terminar el chequeo" do
    campo("paquete_tracking").send_keys("1ZNADIELOTIENE01", :enter)

    assert_evento "etiquetar:trackingLibre"
  end

  test "un tracking con pre-alerta no pita «libre»: tiene su propio aviso" do
    campo("paquete_tracking").send_keys(pre_alerta_paquetes(:pap_sin_vincular).tracking, :enter)

    assert_evento "etiquetar:preAlertaMatch"
    assert_not eventos.include?("etiquetar:trackingLibre"),
               "la pre-alerta no es «podés seguir»: es «fijate que tiene pre-alerta»"
  end

  test "el cliente que aparece en la lista pita" do
    find("[data-etiquetar-target=clienteInput]").send_keys("2")
    assert_selector "[data-index]", wait: 5

    assert_evento "etiquetar:clienteEncontrado"
  end

  test "un codigo que no encuentra a nadie no pita" do
    find("[data-etiquetar-target=clienteInput]").send_keys("ZZZZ")
    assert_text "No se encontraron clientes", wait: 5

    assert_not eventos.include?("etiquetar:clienteEncontrado"),
               "«no se encontraron clientes» no es un «podés seguir»"
  end

  private


  # C19-08: la sesión se abre en el tipo de la pre-alerta que se escanea. Antes
  # se clickeaba el primer botón —que no es CER Legacy— y el match sonaba igual
  # **con el modal de conflicto en pantalla**: el beep alegre sobre un paquete
  # que no se podía guardar. Ahora el conflicto lo silencia (suena solo el
  # error), así que este test tiene que escanear en la sesión correcta para
  # escuchar el match de verdad.
  def abrir_etiquetar = abrir_sesion_etiquetar(tipo_envios(:aereo))

  def campo(id) = find("##{id}")

  def escuchar(*nombres)
    page.execute_script(<<~JS, nombres)
      window.__eventos = [];
      arguments[0].forEach(function (n) {
        document.addEventListener(n, function () { window.__eventos.push(n) });
      });
    JS
  end

  def eventos = page.evaluate_script("window.__eventos")

  def assert_evento(nombre)
    assert page.evaluate_script("window.__eventos"), "no se instaló el listener"
    assert_selector "body", wait: 5 # da tiempo a que el fetch vuelva
    Timeout.timeout(5) { sleep 0.1 until eventos.include?(nombre) }
  rescue Timeout::Error
    flunk "nunca sonó #{nombre}; sonaron #{eventos.inspect}"
  end
end
