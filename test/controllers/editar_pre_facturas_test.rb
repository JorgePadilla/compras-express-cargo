require "test_helper"

# PR-P.7 · Editar pre-facturas desde la hoja, y cambiar la hora en lote.
#
# Yusef (`C30-16`): *"el marítimo lo notificamos a las 2 de la tarde mientras
# terminamos el aéreo"* · `C30-18`: *"¿Y si se equivocan con F9? — Pueden
# reversarlo y poner F8"*, mientras el aviso no haya salido (`RP-77`).
class EditarPreFacturasTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @manana = Date.tomorrow
    @pf = pre_facturas(:borrador_juan)
    @pf.update_columns(manifiesto_id: @manifiesto.id, estado: "creado",
                       notificar_at: Time.zone.local(@manana.year, @manana.month, @manana.day, 7, 30),
                       fecha_trabajo: @manana, notificado_at: nil, consolidando_at: nil,
                       auditado_por_id: users(:supervisor_prefactura).id)
    @caja = paquetes(:recibido)
    @caja.update_columns(pre_factura_id: @pf.id, estado: "en_aduana", manifiesto_id: @manifiesto.id)
    @pf.pre_factura_items.create!(concepto: "Flete", paquete: @caja, subtotal: 10, origen: "manual")
  end

  # ── Reprogramar ────────────────────────────────────────────────────────

  test "de 07:30 a 11:30 las programadas del manifiesto, con la fecha de trabajo detrás" do
    ingresar
    patch reprogramar_hoja_de_preparacion_url, params: { manifiesto_id: @manifiesto.id, hora: "11:30" }

    assert_redirected_to hoja_de_preparacion_path
    @pf.reload
    assert_equal [ 11, 30 ], [ @pf.notificar_at.hour, @pf.notificar_at.min ]
    assert_equal @manana, @pf.notificar_at.to_date, "sin fecha, el mismo día"
    assert_equal @manana, @pf.fecha_trabajo
  end

  test "con otra fecha, mueve el día y la fecha de trabajo" do
    ingresar
    otro = @manana + 2
    patch reprogramar_hoja_de_preparacion_url, params: { manifiesto_id: @manifiesto.id, hora: "14:00", fecha: otro.iso8601 }

    @pf.reload
    assert_equal Time.zone.local(otro.year, otro.month, otro.day, 14, 0), @pf.notificar_at
    assert_equal otro, @pf.fecha_trabajo
  end

  test "solo toca las que no avisaron, y no a las consolidando" do
    avisada = pre_facturas(:pendiente_maria)
    hora_vieja = 2.hours.ago.change(sec: 0)
    avisada.update_columns(manifiesto_id: @manifiesto.id, estado: "creado", notificar_at: hora_vieja, notificado_at: 1.hour.ago,
                           auditado_por_id: users(:supervisor_prefactura).id)

    ingresar
    patch reprogramar_hoja_de_preparacion_url, params: { hora: "11:30" }

    assert_equal hora_vieja, avisada.reload.notificar_at, "la que avisó no se mueve"
    assert_equal 11, @pf.reload.notificar_at.hour

    @pf.update_columns(consolidando_at: Time.current, notificar_at: nil)
    patch reprogramar_hoja_de_preparacion_url, params: { hora: "15:00" }
    assert_nil @pf.reload.notificar_at, "una consolidando no tiene hora"
  end

  test "una hora que no se entiende no mueve nada" do
    ingresar
    patch reprogramar_hoja_de_preparacion_url, params: { hora: "once y media" }
    assert_equal 7, @pf.reload.notificar_at.hour
    assert_match(/11:30/, flash[:alert])
  end

  # ── Volver a consolidar ────────────────────────────────────────────────

  test "una programada vuelve a consolidando: sin hora, y las cajas esperando" do
    ingresar
    patch volver_a_consolidar_hoja_de_preparacion_url, params: { pre_factura_id: @pf.id }

    @pf.reload
    assert @pf.consolidando_at.present?
    assert_nil @pf.notificar_at
    assert_equal "consolidando_honduras", @caja.reload.estado
  end

  test "una que ya avisó no vuelve (RP-77)" do
    @pf.update_columns(notificado_at: 1.hour.ago)
    ingresar
    patch volver_a_consolidar_hoja_de_preparacion_url, params: { pre_factura_id: @pf.id }

    assert_nil @pf.reload.consolidando_at
    assert flash[:alert].present?
    assert_raises(PreFactura::YaAvisada) { @pf.volver_a_consolidar! }
  end

  # ── La pantalla ────────────────────────────────────────────────────────

  test "el estado de cada una, el error de aviso a la vista, y sus acciones" do
    @pf.update_columns(notificacion_error: "10/10/2026 07:30 · PQ-000001 tiene una tarea pendiente que bloquea el avance")
    ingresar
    patch hoja_de_preparacion_url, params: { hoja: { modo: "editar" } }
    get hoja_de_preparacion_url

    assert_select "[data-pre-factura=?]", @pf.numero do
      assert_select "[data-aviso='error']", text: /Error de aviso/
      assert_select "[data-notificacion-error]", text: /tarea pendiente que bloquea/
      assert_select "form[action=?] button", volver_a_consolidar_hoja_de_preparacion_path, text: /Volver a consolidar/
    end
    assert_select "form[data-reprogramar='#{@manifiesto.id}']"
  end

  test "programada dice para cuándo; consolidando ofrece abrirla en auditar" do
    ingresar
    patch hoja_de_preparacion_url, params: { hoja: { modo: "editar" } }
    get hoja_de_preparacion_url
    assert_select "[data-aviso='programada']", text: /Programada para #{@pf.notificar_at.strftime("%d/%m")} 07:30/

    @pf.update_columns(consolidando_at: Time.current, notificar_at: nil)
    get hoja_de_preparacion_url
    assert_select "[data-aviso='consolidando']"
    assert_select "a[href=?]", auditar_pre_factura_index_path(pre_factura_id: @pf.id), text: /Abrir en auditar/
  end

  test "«Abrir en auditar» arranca la pantalla con la consolidando reabierta, aunque la hoja esté en «editar»" do
    @pf.update_columns(consolidando_at: Time.current, notificar_at: nil)
    ingresar
    patch hoja_de_preparacion_url, params: { hoja: { modo: "editar" } }

    get auditar_pre_factura_index_url(pre_factura_id: @pf.id)

    assert_response :success
    assert_match(/data-auditar-pre-factura-abrir-value="[^"]*#{@pf.numero}/, response.body)
  end

  # ── fecha_trabajo y notificar_at, desde la otra puerta ─────────────────

  test "cambiar la fecha de trabajo en el formulario de la pre-factura mueve el aviso, con su hora" do
    ingresar
    otro = @manana + 3
    patch pre_factura_url(@pf), params: { pre_factura: { fecha_trabajo: otro.iso8601 } }

    @pf.reload
    assert_equal otro, @pf.fecha_trabajo
    assert_equal Time.zone.local(otro.year, otro.month, otro.day, 7, 30), @pf.notificar_at
  end

  test "editar una que ya avisó no vuelve a mandar el aviso, y su fecha no se mueve" do
    @pf.update_columns(notificado_at: 1.hour.ago, notificar_at: 2.hours.ago.change(sec: 0), fecha_trabajo: Date.current)
    ingresar

    assert_no_enqueued_emails do
      patch pre_factura_url(@pf), params: { pre_factura: { notas: "corregida" } }
      HacerDisponibles.call(ahora: 1.day.from_now)
    end
    assert_equal "corregida", @pf.reload.notas

    patch pre_factura_url(@pf), params: { pre_factura: { fecha_trabajo: (Date.current + 1).iso8601 } }
    assert_equal Date.current, @pf.reload.fecha_trabajo
    assert_response :unprocessable_entity
  end

  private

  def ingresar
    post session_url, params: { email_address: users(:supervisor_prefactura).email_address, password: "password123" }
  end
end
