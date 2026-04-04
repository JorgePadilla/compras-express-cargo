require "test_helper"

class ManifiestosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @digitador = users(:digitador)
    post session_url, params: { email_address: @digitador.email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
  end

  test "should get index" do
    get manifiestos_url
    assert_response :success
  end

  test "should search manifiestos" do
    get manifiestos_url, params: { q: "MA-000001" }
    assert_response :success
  end

  test "should get new" do
    get new_manifiesto_url
    assert_response :success
  end

  test "should create manifiesto" do
    assert_difference("Manifiesto.count") do
      post manifiestos_url, params: { manifiesto: {
        tipo_envio: "AEREO"
      } }
    end
    assert_redirected_to manifiesto_url(Manifiesto.last)
  end

  test "should show manifiesto" do
    get manifiesto_url(@manifiesto)
    assert_response :success
  end

  test "should get edit" do
    get edit_manifiesto_url(@manifiesto)
    assert_response :success
  end

  test "should update manifiesto" do
    patch manifiesto_url(@manifiesto), params: { manifiesto: { tipo_envio: "CKM MARITIMO" } }
    assert_redirected_to manifiesto_url(@manifiesto)
  end

  test "should add paquete to manifiesto" do
    paquete = paquetes(:etiquetado)
    post add_paquete_manifiesto_url(@manifiesto), params: { paquete_id: paquete.id }
    assert_redirected_to manifiesto_url(@manifiesto)
    paquete.reload
    assert_equal @manifiesto, paquete.manifiesto
    assert_equal "en_manifiesto", paquete.estado
  end

  test "should remove paquete from manifiesto" do
    paquete = paquetes(:etiquetado)
    paquete.update!(manifiesto: @manifiesto, estado: "en_manifiesto")

    delete remove_paquete_manifiesto_url(@manifiesto, paquete_id: paquete.id)
    assert_redirected_to manifiesto_url(@manifiesto)
    paquete.reload
    assert_nil paquete.manifiesto_id
    assert_equal "etiquetado", paquete.estado
  end

  test "should enviar manifiesto" do
    paquete = paquetes(:etiquetado)
    paquete.update!(manifiesto: @manifiesto, estado: "en_manifiesto")
    @manifiesto.recalculate_totals!

    patch enviar_manifiesto_url(@manifiesto)
    assert_redirected_to manifiesto_url(@manifiesto)
    @manifiesto.reload
    assert_equal "enviado", @manifiesto.estado
  end

  test "cajero cannot access manifiestos" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    get manifiestos_url
    assert_redirected_to root_path
  end
end
