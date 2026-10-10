require "application_system_test_case"

# PR-C30.15 · «Editar» edita el manifiesto **en su ficha**.
#
# Jorge, 2026-10-10, después de PR-C30.14 (que había hecho de /edit el
# manifiesto entero en otra pantalla): *"it really don't make sense pressing
# editar sends me here, I want to edit the current view plus all what is in
# the manifiesto, something like this view /manifiestos/24"*.
#
# System test porque lo que importa es JS y teclas: la tarjeta se da vuelta
# adentro de su Turbo Frame sin cambiar la URL, la pistola escribe por
# turbo_stream sin pisar lo tecleado, y mientras la tarjeta está abierta las
# teclas son suyas (`data-teclas-alcance`): F8 guarda y no finaliza, F2 cancela
# y no se va, F5 no recarga.
class ManifiestoEditarEnteroSystemTest < ApplicationSystemTestCase
  TARJETA = "turbo-frame#manifiesto-detalles".freeze
  FORMULARIO = "#{TARJETA} form[data-teclas-alcance]".freeze

  setup do
    @supervisor = users(:supervisor_miami)
    @cer = tipo_envios(:cer)
    @sps = sucursales(:zeron_sps)
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami), sucursal_entrega: @sps)
    @consignatario = Consignatario.create!(nombre: "KARSAM TEST", activo: true)

    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id, sucursal_id: @sps.id)
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @supervisor)
    @manifiesto.meter!(@adentro, user: @supervisor, caja_manifiesto: @caja)

    @tarde = paquetes(:recibido)
    @tarde.tareas.update_all(estado: "realizada")
    @tarde.update_columns(tipo_envio_id: @cer.id, sucursal_id: @sps.id)

    ingresar(@supervisor)
  end

  teardown { cerrar_pestanas_extra }

  test "abierto: F6 abre la tarjeta sin cambiar la URL, F8 guarda sin finalizar, y el escaneo sube el conteo" do
    visit manifiesto_path(@manifiesto)
    assert_selector "#manifiesto-acciones-arriba", text: "Solo Finalizar"
    page.execute_script("window.__marcador = 'vivo'")

    tecla(:f6)
    assert_selector FORMULARIO, wait: 5
    assert_current_path manifiesto_path(@manifiesto), ignore_query: false

    within(FORMULARIO) do
      select "KARSAM TEST", from: "Consignatario"
      find("[data-controller='guias-repetidor'] input[name$='[numero]']", match: :first).set("286441-1")
    end

    # F6 con la tarjeta abierta (y el foco afuera de los campos): no vuelve a
    # pedir el formulario encima del abierto, que se llevaría lo elegido.
    find("#{TARJETA} h2", text: "Detalles del Manifiesto").click
    tecla(:f6)
    sleep 0.5
    within(FORMULARIO) { assert_equal @consignatario.id.to_s, find_field("Consignatario").value }

    # F5 con el cursor en la tarjeta: no arma una caja ni recarga la página.
    within(FORMULARIO) { find("[data-controller='guias-repetidor'] input[name$='[numero]']", match: :first).click }
    assert_no_difference -> { @manifiesto.cajas.count } do
      tecla(:f5)
      sleep 0.5
    end
    assert_equal "vivo", page.evaluate_script("window.__marcador"), "F5 recargó la página"
    # El marcador solo no lo prueba: el F5 que manda chromedriver no llega al
    # atajo de recarga del navegador, así que la página «sobrevive» aunque nadie
    # frene la tecla. Lo que la frena es el `preventDefault` del alcance, y eso
    # se ve desde `window`, que recibe el keydown después que `document`.
    page.execute_script(<<~JS)
      window.__f5 = null
      window.addEventListener("keydown", (e) => { if (e.key === "F5") window.__f5 = e.defaultPrevented }, { once: true })
    JS
    tecla(:f5)
    assert_equal true, page.evaluate_script("window.__f5"), "F5 adentro de la tarjeta no se frena: recargaría"
    assert_selector FORMULARIO

    # F8 es «Guardar» de la tarjeta, no «Solo Finalizar» (también F8). Hoy la
    # tarjeta va antes en el DOM, y el primer `data-shortcut` gana: sin mover
    # nada, esto pasaba igual sin el alcance. Se pone «Solo Finalizar» delante,
    # que es justo lo que el alcance tiene que aguantar.
    page.execute_script(<<~JS)
      document.querySelector("#{TARJETA}").before(document.querySelector("#manifiesto-acciones-arriba"))
    JS
    assert_selector "#manifiesto-acciones-arriba + #{TARJETA}"
    tecla(:f8)
    assert_text "Manifiesto actualizado exitosamente", wait: 5
    assert_no_selector FORMULARIO
    within(TARJETA) { assert_text "KARSAM TEST" }
    @manifiesto.reload
    assert @manifiesto.creado?, "F8 en la tarjeta no finaliza"
    assert_equal @consignatario.id, @manifiesto.consignatario_id
    assert_equal [ "286441-1" ], @manifiesto.numeros_de_guia
    assert_selector "#manifiesto-acciones-arriba", text: "Solo Finalizar"
    assert_equal "vivo", page.evaluate_script("window.__marcador"), "guardar no recarga la ficha"

    # La pistola sigue andando después de guardar, y el conteo de la tarjeta sube.
    antes = @manifiesto.cantidad_paquetes
    find("#buscar_paquete").set(@tarde.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @tarde.tracking, wait: 5 }
    assert_selector "#manifiesto-detalles-paquetes", text: (antes + 1).to_s, wait: 5
  end

  test "recibido: «Editar» abre el candado y aterriza con todo editable; lo tecleado sobrevive al escaneo; F2 cancela sin irse" do
    recibir!
    visit manifiesto_path(@manifiesto)
    assert_text "finalizado y bloqueado"
    assert_no_selector "#buscar_paquete"
    assert_no_selector "[data-candado='cerrado'] button"

    confirmando { find("[data-shortcut='F6']", text: "Editar").click }
    assert_text "Abierto para corregir", wait: 5
    assert_selector FORMULARIO
    assert_selector "#buscar_paquete"

    # Algo a medio teclear en la tarjeta, y se escanea: la tarjeta no se repinta.
    guia = "[data-controller='guias-repetidor'] input[name$='[numero]']"
    within(FORMULARIO) { find(guia, match: :first).set("XYZ-9") }
    antes = @manifiesto.reload.cantidad_paquetes
    find("#buscar_paquete").set(@tarde.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @tarde.tracking, wait: 5 }
    assert_selector "#manifiesto-detalles-paquetes", text: (antes + 1).to_s, wait: 5
    within(FORMULARIO) { assert_equal "XYZ-9", find(guia, match: :first).value }

    # F2 (con el cursor en la pistola, afuera de la tarjeta) es «Cancelar» de
    # la tarjeta, no «Volver» a la lista.
    tecla(:f2)
    assert_no_selector FORMULARIO, wait: 5
    # Sigue en la ficha. (La URL conserva el `?editar=1` con que aterrizó: el
    # frame cambia la tarjeta, no la dirección.)
    assert_current_path manifiesto_path(@manifiesto), ignore_query: true
    assert_text "Abierto para corregir"
    assert_empty @manifiesto.reload.numeros_de_guia, "cancelar no guarda"

    within("#manifiesto-acciones-arriba") { click_on "Cerrar edición" }
    assert_text "finalizado y bloqueado", wait: 5
    assert_no_selector "#buscar_paquete"
  end

  # La regla del modal sigue valiendo después del alcance: con «Eliminar
  # paquetes» abierto, F8 no guarda la tarjeta que quedó atrás.
  test "F8 con «Eliminar paquetes» abierto no guarda la tarjeta de atrás" do
    visit manifiesto_path(@manifiesto, editar: 1)
    assert_selector FORMULARIO
    within(FORMULARIO) { find("label", text: "Es prioridad").click }

    click_on "Eliminar paquetes"
    assert_selector "[data-manifiesto-quitar-target='modal'][open]", wait: 3
    tecla(:f8)
    sleep 0.5

    assert_no_text "Manifiesto actualizado exitosamente"
    assert_selector "[data-manifiesto-quitar-target='modal'][open]"
    assert_not @manifiesto.reload.es_prioridad?
  end

  private

  def recibir!
    FinalizarManifiesto.new(@manifiesto, user: @supervisor).call
    recepcion = RecibirManifiesto.new(@manifiesto.reload, user: @supervisor)
    recepcion.recibir_caja!(@caja)
    recepcion.finalizar!
    assert @manifiesto.reload.recibido?
  end

  def tecla(k)
    page.driver.browser.action.send_keys(k).perform
  end

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end
end
