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

    escanear @qr
    assert_text @cliente.codigo, wait: 5
    assert_text "1 volumen · 2 paquetes · faltan 2"

    escanear @cajas.first.tracking
    assert_text "faltan 1", wait: 5
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    # C31-17 · F9 pregunta cuántas etiquetas, con los volúmenes puestos; Enter
    # imprime.
    nueva = cuantas_etiquetas(:f9, esperadas: 1)
    hasta_que("no se guardó la pre-factura") { PreFactura.where(auditado_por: @user).exists? }

    pf = PreFactura.where(auditado_por: @user).last
    assert_equal 1, pf.etiquetas
    assert_equal [ 14, 5 ], [ pf.notificar_at.hour, pf.notificar_at.min ]
    assert_equal @cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    within_window(nueva) { assert_no_current_path "about:blank", wait: 5 }
    assert_text "guardada", wait: 5
  end

  # Jorge, 2026-10-10: *"estoy pegando este QR de un volumen y no funciona"*.
  # El ícono de /medicion/volumenes copia el QR entero; pegarlo es una lectura,
  # sin el Enter que manda la pistola.
  test "pegar el QR de un volumen lo lee solo, sin Enter" do
    preparar_la_hoja

    pegar @qr
    assert_text "1 volumen · 2 paquetes · faltan 2", wait: 5
    assert_equal "", find("#codigo_auditoria").value

    pegar @cajas.first.tracking
    assert_text "faltan 1", wait: 5
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

  # PR-P.11a · RP-89 · Una tanda prepagada en Miami se audita como cualquiera,
  # y la pantalla avisa que se cobra el simbólico (antes: la puerta a mano).
  test "una tanda prepagada en Miami avisa el simbólico y las líneas lo muestran" do
    @cajas.each { |c| c.update_columns(prepagado_miami: true, prepagado_miami_metodo: "efectivo") }
    preparar_la_hoja
    visit auditar_pre_factura_index_path
    escanear @qr

    assert_text "2 paquetes prepagados en Miami: se cobra el simbólico de US$1.00 c/u", wait: 5
    assert_text "PREPAGADO EN MIAMI"
  end

  # PR-P.6 · F8 deja la pre-factura consolidando; cuando llega lo que faltaba,
  # escanear un volumen suyo la reabre, se le agrega la tanda nueva, y F9 la
  # programa.
  test "F8 consolidando, después la tanda nueva, y F9" do
    # Mañana: si la hora ya pasó, F9 avisa al instante y las cajas no se quedan
    # en aduana, que es lo que este test mira.
    preparar_la_hoja(hora: "15:20", fecha: 1.day.from_now.to_date.iso8601)
    visit auditar_pre_factura_index_path
    escanear @qr
    escanear @cajas.first.tracking
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    cuantas_etiquetas(:f8, esperadas: 1)
    hasta_que("F8 no guardó") { PreFactura.where(auditado_por: @user).where.not(consolidando_at: nil).exists? }
    pf = PreFactura.where(auditado_por: @user).last
    assert_nil pf.notificar_at
    cerrar_pestanas_extra

    # Llega lo que faltaba: una tanda nueva del mismo cliente.
    nueva = Paquete.create!(tracking: "1ZNUEVA#{SecureRandom.hex(4).upcase}", cliente: @cliente, tipo_envio: @cer,
                            sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                            estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    nuevo, = MedirBulto.new(user: @user).guardar!(paquete_ids: [ nueva.id ], volumenes: [ { peso: "3" } ])

    escanear @qr
    assert_text "Agregando a la pre-factura #{pf.numero}", wait: 5
    escanear "MED #{nueva.reload.tracking} 3.00"
    assert_text "faltan 1", wait: 5
    escanear nueva.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    # Dos volúmenes ya: la tanda vieja y la nueva.
    cuantas_etiquetas(:f9, esperadas: 2)
    hasta_que("F9 no programó") { pf.reload.consolidando_at.nil? && pf.notificar_at.present? }

    assert_equal [ 15, 20 ], [ pf.notificar_at.hour, pf.notificar_at.min ]
    assert_equal [ @bulto.id, nuevo.id ].sort, pf.pre_factura_items.where(origen: "volumen").pluck(:bulto_id).sort
    assert_equal "en_aduana", nueva.reload.estado
  end

  # C34-07 · Lista 14 · El consolidado al que le falta uno: el volumen entra
  # con el aviso, y F9 pregunta antes de avisar. Antes salía «es de un grupo
  # que todavía no está completo» y no se podía ni empezar.
  test "consolidado incompleto: se audita con el aviso y F9 pregunta «¿está seguro?»" do
    pa = PreAlerta.create!(numero_documento: "PA-SYS#{SecureRandom.hex(3).upcase}", cliente: @cliente,
                           tipo_envio: @cer, consolidado: true, con_reempaque: true, estado: "pre_alerta",
                           titulo: "Consolidado", creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    %w[1ZSYSCONS000001 1ZSYSCONS000002].each { |t| pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto", fecha: Date.current) }
    una = pa.pre_alerta_paquetes.order(:id).first.paquete
    una.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    una.reload.update!(estado: "en_aduana", manifiesto: @manifiesto, peso: 2)
    MedirBulto.new(user: @user).guardar!(paquete_ids: [ una.id ], volumenes: [ { peso: "2" } ])

    preparar_la_hoja(fecha: 1.day.from_now.to_date.iso8601)
    escanear "MED #{una.reload.tracking} 2.00"
    assert_text "#{pa.numero_documento} no está completo: falta 1 que no ha llegado a Miami", wait: 5
    escanear una.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    page.driver.browser.action.send_keys(:f9).perform
    find("[data-auditar-pre-factura-target='etiquetasModal'][open]", wait: 5)
    page.driver.browser.action.send_keys(:enter).perform
    assert_selector "[data-auditar-pre-factura-target='preguntaModal'][open]", text: "¿Está seguro que desea notificarlo?", wait: 5
    assert_not PreFactura.where(auditado_por: @user).exists?, "la pregunta no guarda"

    window_opened_by { click_on "Sí, notificar" }
    hasta_que("el «Sí» no guardó") { PreFactura.where(auditado_por: @user).where.not(notificar_at: nil).exists? }
    assert_equal PreFactura.where(auditado_por: @user).last.id, una.reload.pre_factura_id
  end

  # C34-08 · Lista 9 · *"Un modal que le diga para dónde va… cuando escanean
  # el QR de peso… y al final, cuando impriman la etiqueta también"*.
  test "el cliente de otra sucursal: modal rojo al escanear el volumen, y lo repite al imprimir" do
    @cajas.each { |c| c.update_columns(sucursal_id: sucursales(:humuya_tgu).id) }
    preparar_la_hoja(fecha: 1.day.from_now.to_date.iso8601)

    escanear @qr
    assert_selector "[data-auditar-pre-factura-target='sucursalModal'][open]", text: "Va para Humuya TGU", wait: 5
    page.driver.browser.action.send_keys(:enter).perform
    assert_no_selector "[data-auditar-pre-factura-target='sucursalModal'][open]", wait: 5

    escanear @cajas.first.tracking
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5
    page.driver.browser.action.send_keys(:f9).perform
    assert_selector "[data-auditar-pre-factura-target='etiquetasModal'][open]", text: "Va para Humuya TGU", wait: 5
  end

  # C31-17 · *"Cuántas etiquetas el F9"*: se cambia el número, sale con eso
  # —una por bolsa, «i de N»— y queda guardado para reimprimir.
  test "F9 pregunta cuántas etiquetas: se cambia a 3 y salen 3" do
    preparar_la_hoja
    escanear @qr
    escanear @cajas.first.tracking
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    page.driver.browser.action.send_keys(:f9).perform
    input = find("[data-auditar-pre-factura-target='etiquetasInput']")
    assert_equal "1", input.value
    input.send_keys(:backspace, "3")
    nueva = window_opened_by { input.send_keys(:enter) }

    hasta_que("no se guardó con 3 etiquetas") { PreFactura.where(auditado_por: @user, etiquetas: 3).exists? }
    within_window(nueva) do
      assert_selector ".entrega", count: 3, wait: 5
      assert_selector ".bolsa", text: "3 de 3"
    end
  end

  test "Escape en «¿Cuántas etiquetas?» vuelve sin guardar, y la pistola sigue" do
    preparar_la_hoja
    escanear @qr
    escanear @cajas.first.tracking
    escanear @cajas.last.tracking
    assert_selector "[data-auditar-pre-factura-target='finModal'][open]", wait: 5

    page.driver.browser.action.send_keys(:f9).perform
    assert_selector "[data-auditar-pre-factura-target='etiquetasModal'][open]", wait: 5
    page.driver.browser.action.send_keys(:escape).perform

    assert_no_selector "[data-auditar-pre-factura-target='etiquetasModal'][open]", wait: 3
    assert_equal 0, PreFactura.where(auditado_por: @user).count
    assert_equal 1, page.driver.browser.window_handles.size, "abrió la pestaña de la etiqueta sin guardar"
    hasta_que("el foco no volvió al campo de la pistola") { page.evaluate_script("document.activeElement.id") == "codigo_auditoria" }
  end

  private

  # F9 o F8 → «¿Cuántas etiquetas?» con los volúmenes puestos → Enter abre la
  # etiqueta. Devuelve la pestaña.
  def cuantas_etiquetas(tecla, esperadas:)
    page.driver.browser.action.send_keys(tecla).perform
    input = find("[data-auditar-pre-factura-target='etiquetasModal'][open] [data-auditar-pre-factura-target='etiquetasInput']", wait: 5)
    assert_equal esperadas.to_s, input.value, "el número por defecto son los volúmenes"
    window_opened_by { page.driver.browser.action.send_keys(:enter).perform }
  end

  def preparar_la_hoja(hora: "07:30", fecha: nil)
    visit hoja_de_preparacion_path
    find("label", text: @cer.nombre, exact_text: true).click
    click_on "Ver manifiestos"
    find("#hoja_manifiesto_#{@manifiesto.id}", visible: :all).check
    page.execute_script("document.querySelector('#hoja_hora')._flatpickr.setDate('#{hora}', true)")
    page.execute_script("document.querySelector('#hoja_fecha')._flatpickr.setDate('#{fecha}', true)") if fecha
    # C31-16 · Un solo botón: guarda la hoja y entra a auditar.
    click_on "Guardar y empezar a auditar"
    assert_selector "#codigo_auditoria", wait: 5
  end

  # Un pegado de verdad (Ctrl+V) no anda en el Chrome headless de los tests:
  # se dispara el evento `paste` con su `clipboardData`, que es lo que lee la
  # pantalla.
  def pegar(texto)
    find("#codigo_auditoria").click
    page.execute_script(<<~JS, texto)
      const dt = new DataTransfer()
      dt.setData("text/plain", arguments[0])
      document.querySelector("#codigo_auditoria")
        .dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true, cancelable: true }))
    JS
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
