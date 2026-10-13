require "application_system_test_case"

# C31-01 · La prueba que Yusef hizo en staging el 2026-10-12, **en el orden en
# que la hizo**, de la ficha del manifiesto hasta que la carga llega a aduana.
#
#   > "Escaneo y le pongo una caja, le pongo 20 libras y le doy a agregar e
#   >  imprimir… siempre está sin escanear… no podemos avanzar, nos está
#   >  bloqueando todo."
#
# Lo que pasaba: la barra de abajo («Agregar paquetes») metía el paquete al
# manifiesto **sin caja y sin estado**. La caja quedaba «vacía», el paquete
# «sin escanear», y al recibir en San Pedro el escaneo de la caja movía a
# aduana a nadie: la pre-factura decía que la carga no había llegado.
#
# Cada test de este archivo arranca en `/manifiestos` y sigue solo con clics y
# la pistola, como `flujo_del_manifiesto_test`.
class LaPruebaDeYusefTest < ApplicationSystemTestCase
  setup do
    @tipo = tipo_envios(:aereo)
    @paquete = paquetes(:recibido)
    # Recibido en Miami: es de donde sale el manifiesto, y lo que «Empacar sin
    # escanear» barre.
    @paquete.update!(tipo_envio: @tipo, sucursal_recepcion_id: sucursales(:miami).id)
    # El de fixture trae una tarea abierta que no deja empacar: lo que se
    # recorre acá es el camino normal.
    @paquete.tareas.update_all(estado: "realizada")
  end

  def crear_manifiesto
    ingresar(users(:supervisor_miami))
    visit manifiestos_path
    click_on "Nuevo Manifiesto"
    check "manifiesto_tipo_envio_#{@tipo.id}", allow_label_click: true
    click_on "Crear manifiesto"
    assert_selector "h1", text: /M[A-Z]{3}\d{4}/, wait: 5
    Manifiesto.order(:id).last
  end

  def agregar_caja(peso: "20")
    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: peso
    click_on "Agregar caja"
    assert_text "1 bulto(s)", wait: 5
  end

  # Que Stimulus conecte antes de teclear: si no, el Enter cae en un campo sin
  # nadie que lo escuche (lo mismo que `recibir_varios_manifiestos_test`).
  def esperar_la_pistola_de_recepcion
    page.document.synchronize(10) do
      conectado = page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector("[data-controller~='recepcion-carga']")
          return !!(el && window.Stimulus?.getControllerForElementAndIdentifier(el, "recepcion-carga"))
        })()
      JS
      raise Capybara::ExpectationNotMet, "la pistola no conectó" unless conectado
    end
  end

  def escanear_en_la_barra(codigo)
    find("#buscar_paquete").set(codigo)
    find("#buscar_paquete").send_keys(:enter)
  end

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end

  test "armar la caja, escanear en la barra, finalizar y recibir: la carga llega a aduana" do
    manifiesto = crear_manifiesto
    agregar_caja

    escanear_en_la_barra(@paquete.numero_recepcion)
    within("#manifiesto-paquetes") { assert_text @paquete.tracking, wait: 5 }

    caja = manifiesto.cajas.first
    assert_eventualmente("el paquete escaneado no entró a la caja", wait: 5) do
      @paquete.reload.caja_manifiesto_id == caja.id
    end
    assert_equal "empacado", @paquete.estado, "escaneado en su caja es empacado"
    within("[data-caja='#{caja.letra}']") { assert_text "1 paquete(s)" }
    within("#manifiesto-paquetes") { assert_no_text "sin escanear" }

    confirmando { click_button "Solo Finalizar", match: :first }
    assert_eventualmente("no salió a enviado", wait: 10) { @paquete.reload.estado == "enviado_honduras" }

    # San Pedro: escanea la 4×6 de la caja y lo de adentro pasa a aduana. Recibe
    # pre-factura, no Miami (C21-07).
    Capybara.reset_session!
    ingresar(users(:supervisor_prefactura))
    visit recepcion_carga_index_path
    esperar_la_pistola_de_recepcion
    find("#codigo_caja").send_keys(caja.codigo, :enter)
    assert_eventualmente("escanear la caja no movió su carga a aduana", wait: 10) do
      @paquete.reload.estado == "en_aduana"
    end
    assert_includes Paquete.facturables, @paquete, "en aduana ya se puede pre-facturar"
  end

  test "empacar sin escanear deja el paquete empacado" do
    crear_manifiesto

    confirmando { click_on "Empacar sin escanear" }
    assert_text "sin escanear", wait: 5

    assert_eventualmente("no entró al manifiesto", wait: 5) { @paquete.reload.manifiesto_id.present? }
    assert_equal "empacado", @paquete.estado,
                 "C31-01: «está bien que esté sin escanear… pero cambia el estatus»"
  end

  test "la ficha ya no manda a empacar escaneando: se escanea en la barra" do
    crear_manifiesto
    agregar_caja

    assert_no_link "Empacar escaneando"
    assert_selector "[data-caja-activa]", text: /A/, wait: 5
  end
end
