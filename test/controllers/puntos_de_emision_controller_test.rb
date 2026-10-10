require "test_helper"

# PR-F1.3 · Los puntos de emisión se crean y se editan desde «Facturación SAR».
class PuntosDeEmisionControllerTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end

  test "crea el punto de una sucursal que no tenía" do
    puntos_de_emision(:sam).destroy!

    get new_punto_de_emision_url(sucursal_id: sucursales(:san_manuel).id)
    assert_response :success
    assert_select "option[selected][value=?]", sucursales(:san_manuel).id.to_s
    # Solo ofrece las que no tienen punto.
    assert_select "select#punto_de_emision_sucursal_id option", text: "Zeron SPS", count: 0

    assert_difference -> { PuntoDeEmision.count } do
      post puntos_de_emision_url, params: { punto_de_emision: { sucursal_id: sucursales(:san_manuel).id,
                                                                establecimiento: "002", punto: "001", activo: "1" } }
    end
    assert_redirected_to autorizaciones_sar_path
  end

  test "números mal escritos vuelven al formulario" do
    puntos_de_emision(:sam).destroy!
    post puntos_de_emision_url, params: { punto_de_emision: { sucursal_id: sucursales(:san_manuel).id,
                                                              establecimiento: "2", punto: "001" } }
    assert_response :unprocessable_entity
  end

  test "un punto sin CAIs cambia de números; con CAIs solo se activa o desactiva" do
    tgu = puntos_de_emision(:tgu)
    patch punto_de_emision_url(tgu), params: { punto_de_emision: { punto: "002" } }
    assert_equal "002", tgu.reload.punto

    sps = puntos_de_emision(:sps)
    patch punto_de_emision_url(sps), params: { punto_de_emision: { punto: "009" } }
    assert_response :unprocessable_entity
    assert_equal "001", sps.reload.punto

    patch punto_de_emision_url(sps), params: { punto_de_emision: { activo: "0" } }
    assert_not sps.reload.activo?
  end

  test "quien no es admin no entra" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get new_punto_de_emision_url
    assert_redirected_to root_path
  end
end
