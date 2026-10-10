require "application_system_test_case"

# PR-P.5 · El recorrido entero, como lo dibujó Yusef: la hoja → el QR de un
# volumen trae la tanda → cada etiqueta de Miami «pertenece» → F9 guarda,
# abre la etiqueta y deja el aviso programado a la hora de la hoja.
class AuditarPreFacturaSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    @cajas = 2.times.map do
      Paquete.create!(tracking: "1ZSYS#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: @cer,
                      sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                      estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "4" } ])
    @qr = "MED #{@cajas.first.reload.tracking} 4.00"

    ingresar(@user)
  end

  teardown { cerrar_pestanas_extra }

  test "hoja, volumen, cajas y F9: la pre-factura queda con la hora de la hoja" do
    preparar_la_hoja(hora: "14:05")
    click_on "Empezar a auditar"
    assert_selector "#codigo_auditoria", wait: 5

    escanear @qr
    assert_text @cliente.codigo, wait: 5
    assert_text "1 volumen · 2 cajas · faltan 2"

    escanear @cajas.first.tracking
    assert_text "faltan 1", wait: 5
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    nueva = window_opened_by { page.driver.browser.action.send_keys(:f9).perform }
    hasta_que("no se guardó la pre-factura") { PreFactura.where(auditado_por: @user).exists? }

    pf = PreFactura.where(auditado_por: @user).last
    assert_equal [ 14, 5 ], [ pf.notificar_at.hour, pf.notificar_at.min ]
    assert_equal @cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    within_window(nueva) { assert_no_current_path "about:blank", wait: 5 }
    assert_text "guardada", wait: 5
  end

  test "Enter no guarda: ni en el campo, ni con el modal abierto" do
    preparar_la_hoja
    visit auditar_pre_factura_index_path
    escanear @qr
    escanear @cajas.first.tracking
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    page.driver.browser.action.send_keys(:enter).perform
    assert_no_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 3
    find("#codigo_auditoria").send_keys(:enter)

    assert_equal 0, PreFactura.where(auditado_por: @user).count
  end

  test "una caja que no corresponde se dice, y no se marca" do
    preparar_la_hoja
    visit auditar_pre_factura_index_path
    escanear @qr
    ajena = Paquete.create!(tracking: "1ZAJENA#{SecureRandom.hex(4).upcase}", cliente: clientes(:maria), tipo_envio: @cer,
                            estado: "en_aduana", descripcion: "x", peso: 1, sucursal_recepcion: sucursales(:miami))
    escanear ajena.tracking

    assert_text "no corresponde", wait: 5
    assert_text "faltan 2"
  end

  private

  def preparar_la_hoja(hora: "07:30")
    visit hoja_de_preparacion_path
    find("label", text: @cer.nombre, exact_text: true).click
    click_on "Ver manifiestos"
    find("#hoja_manifiesto_#{@manifiesto.id}", visible: :all).check
    page.execute_script("document.querySelector('#hoja_hora')._flatpickr.setDate('#{hora}', true)")
    click_on "Guardar la hoja"
    assert_selector "a", text: "Empezar a auditar", wait: 5
  end

  def escanear(codigo)
    find("#codigo_auditoria").send_keys(codigo, :enter)
  end

  def hasta_que(mensaje, wait: Capybara.default_max_wait_time)
    page.document.synchronize(wait, errors: [ Capybara::ExpectationNotMet ]) do
      raise Capybara::ExpectationNotMet, mensaje unless yield
    end
    assert true
  rescue Capybara::ExpectationNotMet
    flunk mensaje
  end
end
