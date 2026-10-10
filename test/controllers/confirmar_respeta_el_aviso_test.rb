require "test_helper"

# PR-P.9 · «Confirmar» y «Facturar» a mano sobre una pre-factura que salió de
# la auditoría.
#
# Una programada (F9) pasa a disponible **sola**, a la hora de la hoja, y
# `HacerDisponibles` pregunta antes por las tareas que bloquean. «Confirmar»
# hacía lo mismo en el acto: se salteaba la hora y la guarda. Sobre una
# consolidando (F8) soltaba cajas que esperan a otras, y «Facturar» la dejaba
# sin hora: nadie las iba a pasar nunca a disponible.
class ConfirmarRespetaElAvisoTest < ActionDispatch::IntegrationTest
  setup do
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @pf = pre_facturas(:borrador_juan)
    @pf.update_columns(manifiesto_id: @manifiesto.id, estado: "creado", notificar_at: 2.hours.from_now.change(sec: 0),
                       notificado_at: nil, consolidando_at: nil, notificacion_error: nil)
    # Una caja nueva y no `paquetes(:recibido)`: esa fixture trae una tarea que
    # bloquea, y `confirmar!` la frenaría por otro motivo.
    @caja = Paquete.create!(tracking: "1ZPP9CONFIRMAR01", cliente: @pf.cliente, tipo_envio: tipo_envios(:cer),
                            sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Ropa", peso: 2,
                            manifiesto: @manifiesto, pre_factura: @pf)
    @pf.pre_factura_items.create!(concepto: "Flete", paquete: @caja, subtotal: 10, origen: "manual")
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end

  test "una programada no se confirma a mano: las cajas esperan la hora" do
    get edit_pre_factura_path(@pf)
    assert_select "form[action='#{confirmar_pre_factura_path(@pf)}']", count: 0
    assert_select "[data-motivo-sin-confirmar]", text: /Se avisa sola el .* a las \d\d:\d\d/

    post confirmar_pre_factura_path(@pf)

    assert_redirected_to edit_pre_factura_path(@pf)
    assert_match(/Se avisa sola/, flash[:alert])
    assert @pf.reload.creado?
    assert_equal "en_aduana", @caja.reload.estado
  end

  test "una programada cuyo aviso falló tampoco: es la guarda que el job reintenta" do
    @pf.update_columns(notificar_at: 1.hour.ago.change(sec: 0), notificacion_error: "tiene una tarea pendiente")

    post confirmar_pre_factura_path(@pf)

    assert_match(/Se avisa sola/, flash[:alert])
    assert_equal "en_aduana", @caja.reload.estado
  end

  test "una programada sí se factura: a la hora el job igual pasa las cajas y avisa" do
    get edit_pre_factura_path(@pf)
    assert_select "form[action='#{facturar_pre_factura_path(@pf)}']"
  end

  test "una consolidando no se confirma ni se factura" do
    @pf.update_columns(consolidando_at: Time.current, notificar_at: nil)

    get edit_pre_factura_path(@pf)
    assert_select "form[action='#{confirmar_pre_factura_path(@pf)}']", count: 0
    assert_select "form[action='#{facturar_pre_factura_path(@pf)}']", count: 0
    assert_select "[data-motivo-sin-confirmar]", text: /consolidando/

    post facturar_pre_factura_path(@pf)
    assert_redirected_to edit_pre_factura_path(@pf)
    assert_match(/consolidando/, flash[:alert])
    assert @pf.reload.creado?, "no se facturó"
  end

  test "una hecha a mano, sin aviso, se confirma como siempre" do
    @pf.update_columns(notificar_at: nil, manifiesto_id: nil)

    get edit_pre_factura_path(@pf)
    assert_select "form[action='#{confirmar_pre_factura_path(@pf)}']"

    post confirmar_pre_factura_path(@pf)
    assert_nil flash[:alert]
    assert @pf.reload.pendiente?
    assert_equal "disponible_entrega", @caja.reload.estado
  end

  test "ya avisada, la pre-factura vuelve a ser una más" do
    @pf.update_columns(notificar_at: 1.hour.ago.change(sec: 0), notificado_at: 1.minute.ago)

    assert_nil @pf.motivo_para_no_confirmar
    assert_nil @pf.motivo_para_no_facturar
  end
end
