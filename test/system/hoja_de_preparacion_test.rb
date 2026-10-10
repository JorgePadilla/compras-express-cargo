require "application_system_test_case"

# PR-P.4 · C30-15 · Los tres pasos de la hoja, como en el diagrama de Yusef:
# servicios → manifiestos → fecha de trabajo. Va como system test porque la
# hora pasa por el picker del proyecto (flatpickr en modo solo hora) y lo que
# se prueba es que lo que se ve es lo que se guarda.
class HojaDePreparacionSystemTest < ApplicationSystemTestCase
  setup do
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    paquetes(:recibido).update_columns(manifiesto_id: @manifiesto.id, tipo_envio_id: @cer.id,
                                       estado: "en_aduana", pre_factura_id: nil, venta_id: nil)
    Configuracion.where(clave: "prefactura_hora_disponible").delete_all

    ingresar(users(:supervisor_prefactura))
  end

  test "servicio, manifiesto y hora, y la hoja se acuerda" do
    visit hoja_de_preparacion_path
    assert_text "¿Qué vas a trabajar?"
    assert_selector "a[href='#{hoja_de_preparacion_path}']", visible: :all, minimum: 1
    assert_text "Elegí arriba los servicios"

    # 1 · El servicio.
    find("label", text: @cer.nombre, exact_text: true).click
    click_on "Ver manifiestos"

    # 2 · El manifiesto.
    within("[data-manifiesto='#{@manifiesto.numero}']") do
      assert_text "0 de 1 paquetes pre-facturados"
      find("#hoja_manifiesto_#{@manifiesto.id}", visible: :all).check
    end

    # 3 · La hora: 07:30 por defecto, y se cambia sin segundos.
    assert_equal "07:30", find("#hoja_hora", visible: :all).value
    page.execute_script("document.querySelector('#hoja_hora')._flatpickr.setDate('14:05', true)")
    click_on "Guardar la hoja"

    assert_equal "14:05", find("#hoja_hora", visible: :all).value, wait: 5
    assert find("#hoja_manifiesto_#{@manifiesto.id}", visible: :all).checked?
    assert find("#hoja_tipo_envio_#{@cer.id}", visible: :all).checked?
    assert_selector "button[disabled]", text: "Empezar a auditar"

    # Se acuerda al volver, como /etiquetar.
    visit root_path
    visit hoja_de_preparacion_path
    assert_equal "14:05", find("#hoja_hora", visible: :all).value

    # Y se cierra.
    confirmando { click_on "Cerrar la hoja" }
    assert_text "Hoja de preparación cerrada", wait: 5
    assert_equal "07:30", find("#hoja_hora", visible: :all).value
  end

  private

  def confirmando(&clic)
    accept_confirm(&clic)
  rescue Capybara::ModalNotFound
    within(MODAL_CONFIRMAR) { click_on "Confirmar" } if page.has_css?(MODAL_CONFIRMAR, wait: 3)
  end
end
