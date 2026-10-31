require "test_helper"

# C34-11 · *"Yo creé una, sólo era una y no me dejaba borrarla."*
#
# Desde PR-D2 (2026-05-08) cada renglón nace con su paquete «esperado»
# (`PreAlertaPaquete#crear_paquete_esperado`). El portal decidía con
# `paquete_id.nil?`, regla del 2026-04-16, y eso ya no se cumplía nunca:
# ningún renglón guardado se podía borrar. Los tests de antes usan fixtures,
# que no corren el `after_create`, y por eso no lo veían. Acá los renglones
# se crean por el modelo, como los crea el cliente.
class Cuenta::BorrarPreAlertaSinRecibirTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    @pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:aereo), consolidado: false,
                            estado: "pre_alerta", titulo: "Una sola", creado_por_tipo: "cliente",
                            creado_por_id: @cliente.id)
    @pap = @pa.pre_alerta_paquetes.create!(tracking: "1ZSOLOUNA000001", descripcion: "Tenis", fecha: Date.current)
  end

  test "el renglón nace con su esperado, y aun así se puede borrar: anula el esperado" do
    esperado = @pap.reload.paquete
    assert_equal "pre_alerta_estado", esperado.estado, "el renglón ya trae su paquete esperado"

    get edit_cuenta_pre_alerta_url(@pa)
    assert_response :success

    assert_difference("PreAlertaPaquete.count", -1) do
      delete eliminar_paquete_cuenta_pre_alerta_url(@pa, pre_alerta_paquete_id: @pap.id)
    end
    assert_equal "anulado", esperado.reload.estado
  end

  test "lo que Miami ya recibió no se borra" do
    @pap.paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))

    assert_no_difference("PreAlertaPaquete.count") do
      delete eliminar_paquete_cuenta_pre_alerta_url(@pa, pre_alerta_paquete_id: @pap.id)
    end
    assert_match "ya fue recibido", flash[:alert]
  end

  test "la pre-alerta entera se anula desde el portal mientras nada llegó" do
    get edit_cuenta_pre_alerta_url(@pa)
    assert_select "form[action='#{anular_cuenta_pre_alerta_path(@pa)}']"

    delete anular_cuenta_pre_alerta_url(@pa)

    assert_redirected_to cuenta_pre_alertas_url
    assert @pa.reload.anulado?
  end

  test "con algo ya recibido, ni el botón ni la acción la anulan" do
    @pap.paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))

    get edit_cuenta_pre_alerta_url(@pa)
    assert_select "form[action='#{anular_cuenta_pre_alerta_path(@pa)}']", count: 0

    delete anular_cuenta_pre_alerta_url(@pa)
    assert_not @pa.reload.anulado?
    assert_match "ya recibimos", flash[:alert]
  end
end
