require "test_helper"

# C31-01 · La barra de la ficha mete lo que se escanea **en la caja abierta**, y
# lo deja empacado. Yusef, en la prueba del 2026-10-12: *"escaneo y le pongo
# una caja, le pongo 20 libras y le doy a agregar e imprimir… siempre está sin
# escanear… nos está bloqueando todo"*.
class CajaActivaDelManifiestoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:supervisor_miami).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
    @tipo = tipo_envios(:express)
    @manifiesto.update!(tipo_envios: [ @tipo ], sucursal_entrega: nil)
    @paquete = Paquete.create!(tracking: "1ZCAJAACTIVA0001", cliente: clientes(:juan), tipo_envio: @tipo,
                               estado: "recibido_miami", peso: 10)
  end

  def armar_caja
    post manifiesto_cajas_path(@manifiesto), params: { caja_manifiesto: { alto: 10, largo: 10, ancho: 10, peso: 5 } }
    @manifiesto.cajas.order(:id).last
  end

  def agregar(paquete = @paquete)
    post add_paquete_manifiesto_path(@manifiesto), params: { paquete_id: paquete.id }, as: :turbo_stream
  end

  test "la caja recién armada es la abierta: lo escaneado entra en ella, empacado" do
    armar_caja
    nueva = armar_caja

    agregar

    @paquete.reload
    assert_equal nueva.id, @paquete.caja_manifiesto_id, "entra en la última que se armó"
    assert_equal "empacado", @paquete.estado
    assert_match(/entró a la caja #{nueva.letra}/, response.body)
  end

  test "«Usar esta» cambia la caja en la que entra" do
    primera = armar_caja
    armar_caja

    patch usar_manifiesto_caja_path(@manifiesto, primera), as: :turbo_stream
    assert_response :success
    assert_match(/Entra en la caja/, response.body)

    agregar
    assert_equal primera.id, @paquete.reload.caja_manifiesto_id
  end

  test "sin cajas entra suelto, pero empacado" do
    agregar

    @paquete.reload
    assert_nil @paquete.caja_manifiesto_id
    assert_equal "empacado", @paquete.estado
    assert_match(/sin caja/, response.body)
  end

  test "una caja borrada deja de ser la abierta" do
    primera = armar_caja
    segunda = armar_caja
    delete manifiesto_caja_path(@manifiesto, segunda)

    agregar
    assert_equal primera.id, @paquete.reload.caja_manifiesto_id
  end

  # *"Que los ingrese y no tire error."* Antes de C31-01 el escaneo no tocaba
  # el estado y la tarea no importaba; empacándolo, la guarda del modelo
  # habría reventado con un 500.
  test "el de la tarea pendiente entra a la caja sin avanzar, y sin error" do
    caja = armar_caja
    Tarea.create!(paquete: @paquete, titulo: "Revisar", estado: "pendiente", bloquea_avance: true)

    agregar

    assert_response :success
    @paquete.reload
    assert_equal caja.id, @paquete.caja_manifiesto_id
    assert_equal "recibido_miami", @paquete.estado
    assert_match(/tareas pendientes/, response.body)
  end

  test "no se puede cambiar la caja de un manifiesto ya enviado" do
    caja = armar_caja
    @manifiesto.update_columns(estado: "enviado")

    patch usar_manifiesto_caja_path(@manifiesto, caja), as: :turbo_stream

    assert_response :forbidden, "el candado del manifiesto (`exigir_modificable`) también cuida esto"
  end
end
