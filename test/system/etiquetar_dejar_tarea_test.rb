require "application_system_test_case"

# C17-02: dejar una tarea desde la franja de /etiquetar, con la caja en la mano
# y sin salir de la pantalla.
class EtiquetarDejarTareaTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5

    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      find("button[name='tipo_envio_id'][value='#{tipo_envios(:cer).id}']").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  test "se deja una tarea desde la franja y aparece ahi mismo, con el tracking de la pantalla" do
    find("#paquete_tracking").send_keys("1ZDEJARTAREA0001", :enter)
    cliente = find("[data-etiquetar-target=clienteInput]")
    cliente.send_keys("1")
    assert_selector "[data-index]", wait: 5
    cliente.send_keys(:enter)

    assert_text "Dejar una tarea", wait: 5
    click_on "Dejar una tarea"
    fill_in "tarea_titulo", with: "Revisar el contenido"
    click_on "Dejar la tarea"

    within "#tareas-de-la-franja" do
      assert_text "Revisar el contenido", wait: 5
      assert_selector "#tareas-pendientes-count", text: "1"
    end
    assert_text "Tarea dejada para Miami"

    tarea = Tarea.last
    assert_equal "1ZDEJARTAREA0001", tarea.tracking
    assert_equal clientes(:juan).id, tarea.cliente_id
    assert_nil tarea.paquete_id, "todavía no hay paquete: se ata al guardarlo"
  end
end
