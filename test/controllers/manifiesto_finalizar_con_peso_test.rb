require "test_helper"

# PR-C31.4 · Al finalizar: toda caja con peso (`C31-07`) y el aviso con el
# nombre del estado que pidió Yusef (`C31-05`).
class ManifiestoFinalizarConPesoTest < ActionDispatch::IntegrationTest
  setup do
    @supervisor = users(:supervisor_miami)
    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_entrega: sucursales(:zeron_sps))
    @paquete = paquetes(:empacado)
    @paquete.update_columns(tipo_envio_id: tipo_envios(:cer).id)
    @caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), user: @supervisor)
    @manifiesto.meter!(@paquete, user: @supervisor, caja_manifiesto: @caja)
    ingresar(@supervisor)
  end

  test "una caja sin peso frena el cierre y dice cuál" do
    patch finalizar_manifiesto_url(@manifiesto)

    assert_redirected_to manifiesto_url(@manifiesto)
    assert_match "la caja #{@caja.letra}#{@caja.numero_bulto} no tiene peso", flash[:alert]
    assert_match "aunque sea aproximado", flash[:alert]
    assert_equal "creado", @manifiesto.reload.estado
  end

  test "pesada, finaliza y avisa «enviado a Honduras»" do
    @caja.update!(peso: 14)

    patch finalizar_manifiesto_url(@manifiesto)

    assert_equal "enviado", @manifiesto.reload.estado
    assert_match "enviado a Honduras", flash[:notice]

    get manifiestos_url
    assert_select "span", text: "Enviado a Honduras"
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
