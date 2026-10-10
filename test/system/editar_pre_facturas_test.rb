require "application_system_test_case"

# PR-P.7 · Cambiar la hora del aviso de un manifiesto entero, de 07:30 a
# 11:30, desde la hoja en «editar pre-facturas». Va como system test porque la
# hora pasa por el picker del proyecto (flatpickr, solo hora).
class EditarPreFacturasSystemTest < ApplicationSystemTestCase
  setup do
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    manana = Date.tomorrow
    @pfs = [ pre_facturas(:borrador_juan), pre_facturas(:pendiente_maria) ]
    @pfs.each do |pf|
      pf.update_columns(manifiesto_id: @manifiesto.id, estado: "creado", notificado_at: nil, consolidando_at: nil,
                        notificar_at: Time.zone.local(manana.year, manana.month, manana.day, 7, 30), fecha_trabajo: manana)
    end
    ingresar(users(:supervisor_prefactura))
  end

  test "de 07:30 a 11:30, todas las del manifiesto" do
    visit hoja_de_preparacion_path
    find("label", text: "Editar pre-facturas").click
    click_on "Guardar la hoja"
    assert_selector "[data-pre-factura='#{@pfs.first.numero}'] [data-aviso='programada']", text: /07:30/, wait: 5

    page.execute_script("document.querySelector('#reprogramar_hora_#{@manifiesto.id}')._flatpickr.setDate('11:30', true)")
    within("form[data-reprogramar='#{@manifiesto.id}']") { click_on "Cambiar la hora" }

    assert_text "2 pre-facturas reprogramadas para las 11:30", wait: 5
    assert_selector "[data-pre-factura='#{@pfs.first.numero}'] [data-aviso='programada']", text: /11:30/
    assert @pfs.all? { |pf| pf.reload.notificar_at.hour == 11 && pf.notificar_at.min == 30 }
  end
end
