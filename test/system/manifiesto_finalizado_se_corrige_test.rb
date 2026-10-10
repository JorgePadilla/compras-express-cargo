require "application_system_test_case"

# C30-06 · El recorrido de Yusef sobre un manifiesto que ya se fue: está
# bloqueado, el supervisor aprieta «Editar», agrega el que se quedó, saca con
# la pistola el que no se fue, y lo vuelve a cerrar.
#
#   > "Deseo eliminar paquetes, y le vas a decir que sí, y empezás a escanear
#   >  clac, clac, clac."
#   > "Que le demos un botón que diga editar… pero que presionen el botón."
#
# Va como system test porque la mitad es JS: la pistola del modal clasifica y
# después llama al `DELETE` de siempre, que refresca la tabla por turbo_stream.
class ManifiestoFinalizadoSeCorrigeSystemTest < ApplicationSystemTestCase
  setup do
    @supervisor = users(:supervisor_miami)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami))

    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id)
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @supervisor)
    @manifiesto.meter!(@adentro, user: @supervisor, caja_manifiesto: @caja)
    FinalizarManifiesto.new(@manifiesto, user: @supervisor).call

    @tarde = paquetes(:recibido)
    @tarde.tareas.update_all(estado: "realizada")
    @tarde.update_columns(tipo_envio_id: @cer.id)

    ingresar(@supervisor)
  end

  teardown { cerrar_pestanas_extra }

  test "abrir, agregar el que se quedó, sacar escaneando el que no se fue, y cerrar" do
    visit manifiesto_path(@manifiesto)
    assert_text "finalizado y bloqueado"
    assert_no_selector "#buscar_paquete"

    confirmando { within("#manifiesto-acciones-arriba") { click_on "Editar" } }
    assert_text "Abierto para corregir", wait: 5

    # Agregar: la misma pistola de siempre.
    find("#buscar_paquete").set(@tarde.numero_recepcion)
    find("#buscar_paquete").send_keys(:enter)
    within("#manifiesto-paquetes") { assert_text @tarde.tracking, wait: 5 }
    esperar { @tarde.reload.estado == "enviado_honduras" }

    # Sacar: el modal, y clac.
    click_on "Eliminar paquetes"
    assert_selector "[data-manifiesto-quitar-target='modal'][open]", wait: 3
    find("#quitar_paquete").send_keys(@adentro.tracking, :enter)
    within("[data-manifiesto-quitar-target='modal']") { assert_text "sale del manifiesto", wait: 5 }
    within("#manifiesto-paquetes") { assert_no_text @adentro.tracking, wait: 5 }
    assert_equal "1", find("[data-manifiesto-quitar-target='contador']").text

    # Uno que no está acá suena y se dice, sin tocar nada.
    find("#quitar_paquete").send_keys("NOEXISTE999", :enter)
    within("[data-manifiesto-quitar-target='modal']") { assert_text "No existe", wait: 5 }
    click_on "Listo"

    esperar { @adentro.reload.estado == "recibido_miami" }
    assert_nil @adentro.manifiesto_id

    within("#manifiesto-acciones-arriba") { click_on "Cerrar edición" }
    assert_text "finalizado y bloqueado", wait: 5
    assert_no_selector "#buscar_paquete"
  end

  # Una pestaña vieja: el manifiesto se finaliza en otra mientras ésta sigue
  # mostrando la «×». Apretarla no puede sacar nada (lo cuida el servidor), y
  # la pantalla tiene que dejar de mentir: el aviso donde se vea —arriba, con
  # el scroll arriba— y la ficha dibujada como está, sin «×».
  test "pestaña vieja: se finaliza en otra, y la × muestra el candado en vez de los controles viejos" do
    otro = Manifiesto.create!(tipo_envios: [ @cer ], sucursal_origen: sucursales(:miami), user: @supervisor)
    otro.meter!(@tarde, user: @supervisor)

    visit manifiesto_path(otro)
    quitar = "#manifiesto-paquetes a[href*='remove_paquete']"
    assert_selector quitar

    FinalizarManifiesto.new(otro, user: @supervisor).call   # en otra pestaña
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    confirmando { find(quitar).click }

    assert_selector "[role='alert']", text: "aprieta «Editar»", wait: 5
    assert_no_selector quitar
    assert_no_selector "#buscar_paquete"
    arriba = page.evaluate_script("document.querySelector(\"[role='alert']\").getBoundingClientRect().top")
    assert_operator arriba, :>=, 0
    assert_operator arriba, :<, page.evaluate_script("window.innerHeight"), "el aviso quedó fuera de la vista"
    assert_equal otro.id, @tarde.reload.manifiesto_id, "no sacó nada"
  end

  test "bloqueado, las 4×6 se re-imprimen desde la ficha" do
    visit manifiesto_path(@manifiesto)

    nueva = window_opened_by { find("a[aria-label='Imprimir la etiqueta de la caja #{@caja.letra}']").click }
    within_window(nueva) do
      assert_includes page.current_url, "print=true"
      assert_selector ".bulto", wait: 5
    end
  end

  private

  # Lo que escribe el servidor llega después que la pantalla: se espera a la base.
  def esperar(segundos: 8)
    Timeout.timeout(segundos) { sleep 0.1 until yield }
  end

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end
end
