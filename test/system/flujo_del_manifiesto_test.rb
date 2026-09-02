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

    # Hay dos: el bloque de cierre va arriba y abajo. Con la tabla llena, el de
    # arriba queda a una pantalla de distancia.
    confirmando { click_button "Solo Finalizar", match: :first }

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

    # ── `click_button` y no `first(...).click`: el nodo se muere en el medio ──
    #
    # Acá se venía abajo en CI —`StaleElementReferenceError`, ~2 de cada 3
    # corridas— y en local nunca, ni con la suite en paralelo.
    #
    # La causa es el **preview de caché de Turbo**. «Volver al manifiesto» es un
    # GET normal, y esta pantalla ya se había visitado, así que Turbo pinta al
    # instante el snapshot cacheado (`<html data-turbo-preview>`) y recién
    # cuando llega la respuesta fresca reemplaza el body. El `assert_selector`
    # del h1 pasa contra el preview, o sea que no protege de nada.
    #
    # Y ahí está la trampa: `first(...)` ubica el botón **en el preview**,
    # `.click` lo aprieta en un segundo viaje, y si el body fresco entra en el
    # medio el nodo ya no existe. En local la respuesta vuelve tan rápido que la
    # ventana no existe; en CI sí.
    #
    # Se reprodujo a propósito con `demorar("/manifiestos/")` —el helper que ya
    # estaba para hacer observables las carreras— y forzando el swap entre el
    # `first` y el `.click`. Con eso, el A/B es limpio:
    #
    #     first(:button, …)                → MURIÓ
    #     find(:button, …, match: :first)  → SOBREVIVIÓ
    #
    # Porque **`first` no recarga y `find` sí**: Capybara le guarda la query al
    # nodo que devuelve `find` y la vuelve a correr cuando lo encuentra viejo.
    # `click_button` es `find` + `click`, así que hereda el rescate.
    confirmando { click_button "Finalizar e Imprimir", match: :first }
    esperar_pestana_de_impresion
    cerrar_pestanas_extra

    assert_equal "enviado_honduras", @paquete.reload.estado
    assert_equal 1, Manifiesto.last.cajas.count, "la casa no quedó armada"
  end

  # ── El escaneo, que es lo que lo hace rápido ────────────────────────────

  test "escanear y Enter agrega el paquete sin tocar el mouse" do
    abrir_manifiestos
    crear_manifiesto

    find("#buscar_paquete").set(@paquete.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)

    within("#manifiesto-paquetes") { assert_text @paquete.tracking, wait: 5 }
    assert_equal "", find("#buscar_paquete").value,
                 "el campo tiene que quedar vacío para el siguiente escaneo"
  end

  # ── Los cierres, arriba y abajo ─────────────────────────────────────────

  test "los botones de finalizar están arriba y abajo" do
    abrir_manifiestos
    crear_manifiesto
    agregar_el_paquete

    assert_equal 2, all(:button, "Solo Finalizar").size,
                 "con la tabla llena, el de arriba queda a una pantalla de distancia"
    assert_selector "#manifiesto-acciones-arriba button", text: "Solo Finalizar"
    assert_selector "#manifiesto-acciones-abajo button", text: "Solo Finalizar"
  end

  # ── Y el que documenta la puerta misma ──────────────────────────────────

  test "la ficha del manifiesto ofrece empacar escaneando en cuanto hay una casa" do
    abrir_manifiestos
    crear_manifiesto

    # C23-10 · Sin casas no hay nada que **escanear**, y la pantalla de empaque
    # lo diría sola. Ojo: «Empacar sin escanear» sí está desde el principio y a
    # propósito —ése es el camino que no usa casas ni pistola—, así que la
    # afirmación tiene que nombrar cuál de los dos, no decir «Empacar» a secas.
    assert_no_link "Empacar escaneando"

    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "12.5"
    click_on "Agregar caja"

    assert_selector "a", text: "Empacar escaneando", wait: 5
  end
end
