require "application_system_test_case"

# PR-C30.14 · /edit es el manifiesto entero, como la ficha.
#
# Jorge, 2026-10-10, en /manifiestos/21/edit (recibido): *"esta pantalla de
# editar me debería dejar editar todo lo que está en el manifiesto"* · *"editar
# de manifiesto debería ser muy parecido a /manifiestos/22"* · y de la tabla de
# casas: *"los botones en la sección de acciones no están bien"*.
#
# System test porque la mitad es JS y teclas: la pistola clasifica y escribe
# por turbo_stream, el modal de quitar escanea, y F8 es la tecla de Guardar
# que no puede ser la de Finalizar.
class ManifiestoEditarEnteroSystemTest < ApplicationSystemTestCase
  setup do
    @supervisor = users(:supervisor_miami)
    @cer = tipo_envios(:cer)
    @sps = sucursales(:zeron_sps)
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami), sucursal_entrega: @sps)

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

  test "recibido: se abre desde /edit, se agrega y se saca escaneando, y F8 guarda sin finalizar" do
    recibir!
    visit edit_manifiesto_path(@manifiesto)
    assert_text "finalizado y bloqueado"
    assert_no_selector "#buscar_paquete"

    confirmando { within("[data-candado='cerrado']") { click_on "Editar" } }
    assert_text "Abierto para corregir", wait: 5
    assert_equal edit_manifiesto_path(@manifiesto), page.current_path, "«Editar» vuelve a /edit, no a la ficha"

    # Las tres acciones de la caja, en la misma línea (antes el basurero bajaba).
    fila = "tr[data-caja='#{@caja.letra}']"
    alturas = [ "Editar la caja #{@caja.letra}", "Imprimir la etiqueta de la caja #{@caja.letra}",
                "Eliminar caja #{@caja.letra}" ].map { |label| find("#{fila} [aria-label='#{label}']").rect.y }
    assert_operator alturas.max - alturas.min, :<, 2, "las tres acciones no están en la misma línea: #{alturas.inspect}"

    # Agregar: la pistola de siempre. Entra a uno recibido: llega a aduana.
    find("#buscar_paquete").set(@tarde.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @tarde.tracking, wait: 5 }
    esperar { @tarde.reload.estado == "en_aduana" }
    assert_equal @sps.id, @tarde.sucursal_actual_id

    # Sacar escaneando: el de la caja recibida llegó, así que se queda en aduana.
    click_on "Eliminar paquetes"
    assert_selector "[data-manifiesto-quitar-target='modal'][open]", wait: 3
    find("#quitar_paquete").send_keys(@adentro.tracking, :enter)
    within("[data-manifiesto-quitar-target='modal']") { assert_text "sale del manifiesto", wait: 5 }
    within("#manifiesto-paquetes") { assert_no_text @adentro.tracking, wait: 5 }
    click_on "Listo"
    esperar { @adentro.reload.manifiesto_id.nil? }
    assert_equal "en_aduana", @adentro.estado

    # F8 es «Guardar» del encabezado.
    find("label", text: "Es prioridad").click
    tecla(:f8)
    assert_text "Manifiesto actualizado exitosamente", wait: 5
    @manifiesto.reload
    assert @manifiesto.es_prioridad?
    assert @manifiesto.recibido?, "guardar no cambia el estado"
    assert_equal @manifiesto.id, @tarde.reload.manifiesto_id
  end

  # El caso donde F8 sí podía finalizar: uno abierto, con paquetes. En la
  # ficha «Solo Finalizar» lleva F8; en /edit no se pinta, y el turbo_stream
  # de agregar no lo trae de vuelta (repinta `#manifiesto-acciones-*`, que
  # /edit no tiene).
  test "abierto: agregar en /edit no trae «Solo Finalizar», y F8 guarda sin finalizar" do
    visit edit_manifiesto_path(@manifiesto)
    assert_no_text "Solo Finalizar"

    find("#buscar_paquete").set(@tarde.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @tarde.tracking, wait: 5 }
    assert_no_text "Solo Finalizar"

    find("label", text: "Es prioridad").click
    tecla(:f8)
    assert_text "Manifiesto actualizado exitosamente", wait: 5
    assert @manifiesto.reload.creado?, "F8 en /edit no finaliza"
    assert @manifiesto.es_prioridad?
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

  def esperar(segundos: 8)
    Timeout.timeout(segundos) { sleep 0.1 until yield }
  end

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end
end
