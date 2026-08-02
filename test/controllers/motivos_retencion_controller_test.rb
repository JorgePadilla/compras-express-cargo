require "test_helper"

class MotivosRetencionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @motivo = MotivoRetencion.create!(nombre: "Test setup motivo")
  end

  test "index responde 200 para admin" do
    get motivos_retencion_url
    assert_response :success
  end

  test "non-admin queda redirigido" do
    delete session_url
    cajero = users(:cajero)
    post session_url, params: { email_address: cajero.email_address, password: "password123" }
    get motivos_retencion_url
    assert_redirected_to root_path
  end

  test "new responde 200" do
    get new_motivo_retencion_url
    assert_response :success
  end

  test "create motivo válido" do
    assert_difference "MotivoRetencion.count", 1 do
      post motivos_retencion_url,
           params: { motivo_retencion: { nombre: "Caja húmeda", activo: true } }
    end
    assert_redirected_to motivos_retencion_url
  end

  test "create rechaza nombre vacío" do
    assert_no_difference "MotivoRetencion.count" do
      post motivos_retencion_url, params: { motivo_retencion: { nombre: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit responde 200" do
    get edit_motivo_retencion_url(@motivo)
    assert_response :success
  end

  test "update cambia atributos" do
    patch motivo_retencion_url(@motivo),
          params: { motivo_retencion: { nombre: "Nuevo nombre", activo: false } }
    assert_redirected_to motivos_retencion_url
    @motivo.reload
    assert_equal "Nuevo nombre", @motivo.nombre
    assert_not @motivo.activo
  end
end
