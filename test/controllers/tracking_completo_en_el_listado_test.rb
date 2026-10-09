require "test_helper"

# Yusef, 2026-08-18, midiendo el ancho de `/paquetes` con el mouse:
#
#   > *"El tracking necesitamos verlo completo… si no, vamos a tener que estar
#   >  entrando a cada tracking para poder encontrar uno."*
#   > *"Para querer leérselo al cliente."*
#
# Salía con `truncate(…, length: 18)`. Es la misma regla que ya valía para la
# etiqueta impresa —los trackings no se recortan— que nunca había llegado al
# listado.
#
# El ancho sale de donde él lo señaló: *"le puedes poner «rep Miami»… «hn», no
# pones Honduras sino que «hn», cosas así"*.
class TrackingCompletoEnElListadoTest < ActionDispatch::IntegrationTest
  # Un tracking de los largos de verdad: los de USPS pasan de 30 caracteres, y
  # con 18 se cortaban justo donde empieza lo que los distingue.
  LARGO = "420331289205590000000000000001".freeze

  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
  end

  test "el tracking sale entero" do
    # Sobre el enlace y no sobre el `body`: el tracking completo también viaja
    # en el `data-tracking` del checkbox y en el aria-label de Borrar, así que
    # buscarlo en el HTML entero pasa igual con la celda recortada. La mutación
    # lo encontró.
    paquete = crear(tracking: LARGO)

    get paquetes_url

    assert_response :success
    assert_select "a[href=?]", paquete_path(paquete), text: LARGO
  end

  test "el secundario tambien" do
    secundario = "1ZSECUNDARIO00000000000000001"
    crear(tracking: "1Z999COMPLETO01", secundario: secundario)

    get paquetes_url

    assert_select "[title='Tracking secundario']", text: secundario
  end

  test "ningun tracking sale con puntos suspensivos" do
    paquete = crear(tracking: LARGO)

    get paquetes_url

    celda = css_select("a[href='#{paquete_path(paquete)}']").first&.text.to_s
    assert_no_match(/\.\.\.|…/, celda, "la celda del tracking salió recortada")
  end

  # ── El rótulo corto ────────────────────────────────────────────────────

  test "el estado sale abreviado en la tabla" do
    crear(tracking: "1Z999CORTO0001", estado: "recibido_miami")

    get paquetes_url

    assert_includes response.body, "REC MIAMI"
  end

  test "y el largo sigue estando, debajo del mouse" do
    # No se pierde: es el que responde la pregunta del cliente.
    crear(tracking: "1Z999CORTO0002", estado: "recibido_miami")

    get paquetes_url

    assert_includes response.body, "Recibido en Miami"
  end

  test "el rotulo del cliente no se toca" do
    # `ETIQUETAS` es lo que Yusef peleó en A7-13 contra la resistencia de Jorge
    # a alargarlos: *"un cliente me dijo: recibí un WhatsApp que ya tengo
    # disponible el producto, pero entro a la página y me dice que todavía
    # no"*. Acortar eso sería deshacer esa conversación.
    paquete = crear(tracking: "1Z999CORTO0003", estado: "disponible_entrega")
    paquete.update_columns(sucursal_id: sucursales(:humuya_tgu).id)

    assert_equal "Disponible en sucursal #{sucursales(:humuya_tgu).nombre}",
                 ApplicationController.helpers.estado_de(paquete.reload)
  end

  test "el corto se lleva la sucursal en tres letras" do
    # Los tres estados donde la sucursal **es** el dato que falta. Mismo criterio
    # que el rótulo largo, en tres letras.
    paquete = crear(tracking: "1Z999CORTO0004", estado: "disponible_entrega")
    paquete.update_columns(sucursal_id: sucursales(:humuya_tgu).id)

    corto = ApplicationController.helpers.estado_corto(paquete.reload)

    assert_includes corto, "DISPONIBLE"
    assert_includes corto, sucursales(:humuya_tgu).codigo.upcase
  end

  test "todos los estados tienen rotulo corto" do
    # Si aparece un estado nuevo y nadie le pone el corto, cae al nombre crudo
    # de la columna — que es lo que este listado justamente no quiere mostrar.
    sin_corto = Paquete::ESTADOS_SELECCIONABLES.reject { |e| EstadoPaqueteHelper::CORTAS.key?(e) }

    assert_empty sin_corto, "estados sin rótulo corto para la tabla"
  end

  private

  def crear(tracking:, secundario: nil, estado: "recibido_miami")
    Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    tracking: tracking, tracking_secundario: secundario,
                    descripcion: "x", estado: estado, user: users(:admin),
                    sucursal_recepcion: sucursales(:miami))
  end
end
