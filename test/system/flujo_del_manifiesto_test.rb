require "application_system_test_case"

# Los dos caminos del manifiesto, recorridos **haciendo clic**.
#
# Jorge, después de leer el runbook: *"asegurate que todos los pasos sean
# accesibles y visibles y que funcionen"*. Esto es lo que contesta esa pregunta,
# y lo que ningún test de controller puede contestar.
#
# **La regla de estos tests: no se escribe una sola URL después de entrar.**
# Se llega a `/manifiestos` y de ahí en adelante solo se hace clic. Si un paso no
# tiene puerta, el test **no puede avanzar** — no afirma que el link existe, lo
# usa para llegar.
#
# Es la brecha exacta por la que la pantalla de empacar vivió meses sin un solo
# link: `empaque_controller_test` la visita por helper de ruta, como nadie real
# hace, así que pasaba en verde sobre una pantalla a la que no se llegaba. Es la
# misma forma del bug de F2 —el test armaba los params a mano— y la misma
# lección: cuando el test entra por una puerta que el usuario no tiene, prueba
# otra cosa.
class FlujoDelManifiestoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:supervisor_miami))
    @paquete = paquetes(:recibido)
    # El manifiesto solo mueve los paquetes **de los tipos que lleva** (`C21-03`),
    # y de eso depende que «Solo Finalizar» tenga algo que hacer. El de fixture
    # viene sin tipo, así que se le pone el mismo que se elige abajo.
    @tipo = tipo_envios(:aereo)
    @paquete.update!(tipo_envio: @tipo)
    # El de fixture trae una tarea abierta, y `bloquea_avance` es `true` por
    # defecto: con ella puesta el paquete **no puede pasar a empacado**, que es
    # la regla. Se cierra acá porque lo que este test recorre es el camino
    # normal; el del paquete trabado es otro y hoy contesta feo (ver el PR).
    @paquete.tareas.update_all(estado: "realizada")
  end

  # Todo el flujo arranca acá, y es lo único que se escribe.
  def abrir_manifiestos
    visit manifiestos_path
    assert_selector "h1", text: "Manifiestos", wait: 5
  end

  def crear_manifiesto
    click_on "Nuevo Manifiesto"
    assert_selector "h1", wait: 5

    # `C21-03` · El tipo de envío nuestro es obligatorio: sin al menos uno el
    # manifiesto no se puede guardar, porque es lo que decide qué sale.
    # La casilla es `sr-only` —el patrón de selección de `docs/07`, tarjeta con
    # `peer`—, así que se marca por su id dejando que Capybara haga clic en la
    # etiqueta que la envuelve.
    check "manifiesto_tipo_envio_#{@tipo.id}", allow_label_click: true
    click_on "Crear manifiesto"

    assert_selector "h1", text: /M[A-Z]{3}\d{4}/, wait: 5
  end

  # El confirm tiene tres formas según qué alcanzó a montar —Turbo todavía no,
  # `window.confirm` nativo, o el modal de HTML de `shared/_confirm_modal`—.
  # Es el mismo enredo que ya documenta `cerrar_sesion_etiquetar_si_hay_una`.
  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end

  def agregar_el_paquete
    find("input[placeholder*='tracking']").set(@paquete.tracking)
    assert_selector "[data-manifiesto-search-target=results] button", wait: 5
    find("[data-manifiesto-search-target=results] button", match: :first).click
    # Ojo: el tracking también sale en los resultados de la búsqueda. Lo que hay
    # que esperar es que entre a la **tabla del manifiesto**, que es lo que
    # habilita «Solo Finalizar».
    within("#manifiesto-paquetes") { assert_text @paquete.tracking, wait: 5 }
  end

  # ── Camino sin pre-etiqueta ─────────────────────────────────────────────

  test "sin pre-etiqueta: crear, agregar paquetes y finalizar, solo con clics" do
    abrir_manifiestos
    crear_manifiesto
    agregar_el_paquete

    confirmando { click_on "Solo Finalizar" }

    assert_text "enviado", wait: 5
    assert_equal "enviado_honduras", @paquete.reload.estado,
                 "el camino sin pre-etiqueta no dejó la carga en enviado"
  end

  # ── Camino con pre-etiqueta ─────────────────────────────────────────────
  #
  # Éste es el que prueba el link nuevo: sin el botón «Empacar», el paso 4 no
  # tiene puerta y el test se queda parado.

  test "con pre-etiqueta: armar la casa, empacar escaneando y finalizar, solo con clics" do
    abrir_manifiestos
    crear_manifiesto
    agregar_el_paquete

    # La casa: elegir tamaño y pesarla.
    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "12.5"
    click_on "Agregar caja"
    assert_text "1 bulto(s)", wait: 5

    # El paso que no tenía puerta.
    click_on "Empacar"
    assert_selector "h1", text: "Empacar", wait: 5

    # El «pip pip pip»: el paquete entra a la caja escaneándolo.
    find("#codigo_empaque").set(@paquete.numero_recepcion)
    find("#codigo_empaque").send_keys(:enter)
    assert_text @paquete.tracking, wait: 5

    click_on "Volver al manifiesto"
    assert_selector "h1", text: /M[A-Z]{3}\d{4}/, wait: 5

    confirmando { click_on "Finalizar e Imprimir" }
    esperar_pestana_de_impresion
    cerrar_pestanas_extra

    assert_equal "enviado_honduras", @paquete.reload.estado
    assert_equal 1, Manifiesto.last.cajas.count, "la casa no quedó armada"
  end

  # ── Y el que documenta la puerta misma ──────────────────────────────────

  test "la ficha del manifiesto ofrece empacar en cuanto hay una casa" do
    abrir_manifiestos
    crear_manifiesto

    # Sin casas no hay nada que empacar, y la pantalla de empaque lo diría sola.
    assert_no_link "Empacar"

    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "12.5"
    click_on "Agregar caja"

    assert_selector "a", text: "Empacar", wait: 5
  end
end
