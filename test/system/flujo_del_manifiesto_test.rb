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
    # C31-09 · A dónde va: al menos una sucursal, siempre.
    check "manifiesto_sucursal_entrega_#{sucursales(:zeron_sps).id}", allow_label_click: true
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
  # C31-01 · Ya no pasa por /empacar: la caja recién armada es la abierta, y lo
  # que se escanea en la barra de abajo entra en ella. Yusef: *"queremos
  # eliminar ese empacar escaneando… que sea esta barra que está abajo"*.

  test "con pre-etiqueta: armar la casa, escanear en la barra y finalizar, solo con clics" do
    abrir_manifiestos
    crear_manifiesto

    # La casa: elegir tamaño y pesarla.
    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "12.5"
    click_on "Agregar caja"
    assert_text "1 bulto(s)", wait: 5
    assert_selector "[data-caja-activa]", wait: 5

    # El «pip pip pip»: el paquete entra a la caja escaneándolo en la barra.
    find("#buscar_paquete").set(@paquete.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @paquete.tracking, wait: 5 }
    assert_eventualmente("no entró a la caja", wait: 5) { @paquete.reload.caja_manifiesto_id.present? }

    # `click_button` y no `first(...).click`: ver `nodos_que_no_recargan_test`
    # — el preview de caché de Turbo mata el nodo que `first` no recarga.
    confirmando { click_button "Finalizar e Imprimir", match: :first }
    assert_eventualmente("el paquete no pasó a enviado", wait: 15) do
      @paquete.reload.estado == "enviado_honduras"
    end
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

  test "la ficha ya no ofrece empacar escaneando: la barra dice en qué caja entra" do
    abrir_manifiestos
    crear_manifiesto

    # Sin casas, la barra avisa que entra suelto.
    assert_text "Sin cajas: el paquete entra suelto", wait: 5

    find("label", text: tamano_cajas(:mediana).nombre).click
    fill_in "caja_manifiesto_peso", with: "12.5"
    click_on "Agregar caja"

    assert_selector "[data-caja-activa]", text: /Entra en la caja/, wait: 5
    assert_no_link "Empacar escaneando"
  end
end
