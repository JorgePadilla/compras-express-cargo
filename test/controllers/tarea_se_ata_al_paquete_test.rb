require "test_helper"

# C17-02, la otra mitad: la tarea que se dejó mientras se recibía la caja
# termina colgando de la caja al guardarla, en /etiquetar. En /entrega_personal
# queda del cliente: el tracking se genera al guardar y no hay por dónde
# atarla.
class TareaSeAtaAlPaqueteTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:cer).id,
                                                 sucursal_recepcion_id: sucursales(:miami).id }
  end

  def dejar_tarea(tracking)
    post tareas_url, params: { desde_franja: "1", tarea: { cliente_id: @cliente.id, titulo: "Revisar", tracking: tracking } },
                     as: :turbo_stream
    Tarea.last
  end

  test "al guardar el paquete, la tarea de la franja pasa a colgar de el" do
    tarea = dejar_tarea("1ZATAR0000000001")

    post etiquetar_url, params: { paquete: { tracking: "1ZATAR0000000001", cliente_id: @cliente.id,
                                             descripcion: "Caja", peso: 3 } }

    paquete = Paquete.find_by(tracking: "1ZATAR0000000001")
    assert paquete, "no se guardó el paquete"
    assert_equal paquete.id, tarea.reload.paquete_id
  end

  test "en un split, a la Caja 1" do
    tarea = dejar_tarea("1ZATARSPLIT00001")

    post etiquetar_url, params: { paquete: { tracking: "1ZATARSPLIT00001", cliente_id: @cliente.id,
                                             descripcion: "Dos cajas",
                                             cajas: { "1" => { peso: 2 }, "2" => { peso: 5 } } } }

    cajas = Paquete.where(tracking: "1ZATARSPLIT00001")
    assert_equal 2, cajas.size
    assert_equal cajas.min_by(&:numero_caja).id, tarea.reload.paquete_id
  end

  test "una tarea de otro cliente con el mismo tracking no se lleva" do
    ajena = Tarea.create!(cliente: clientes(:maria), titulo: "Ajena", tracking: "1ZATARAJENA00001")

    post etiquetar_url, params: { paquete: { tracking: "1ZATARAJENA00001", cliente_id: @cliente.id,
                                             descripcion: "Caja", peso: 3 } }

    assert_nil ajena.reload.paquete_id
  end

  test "en entrega personal la tarea queda del cliente" do
    post tareas_url, params: { desde_franja: "1", tarea: { cliente_id: @cliente.id, titulo: "Cobrar antes" } },
                     as: :turbo_stream
    tarea = Tarea.last

    post entrega_personal_index_url, params: { paquete: { cliente_id: @cliente.id, descripcion: "Traído al mostrador",
                                                          tipo_envio_id: tipo_envios(:cer).id, peso: 2,
                                                          sucursal_id: sucursales(:miami).id } }

    assert_nil tarea.reload.paquete_id
    get tareas_url
    assert_match(/Cobrar antes/, response.body)
  end
end
