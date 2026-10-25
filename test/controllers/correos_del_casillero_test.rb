require "test_helper"

# C33-05 · Los correos del casillero, desde las pantallas. Yusef, 2026-10-24:
# *"crear casillero nuevo"*, *"es un botón en el perfil de cliente"* y
# *"cuando queramos enviarle información a un correo de una persona no cliente
# aún"*.
class CorreosDelCasilleroTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @cliente = clientes(:juan)
  end

  def entrar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "crear el cliente en /clientes le manda la bienvenida" do
    entrar users(:admin)

    assert_enqueued_email_with CasilleroMailer, :bienvenida, args: -> (args) { args.first.email == "nuevo@test.com" } do
      post clientes_url, params: { cliente: { sucursal_retiro_id: sucursales(:humuya_tgu).id, nombre: "Nuevo",
                                              apellido: "Cliente De Prueba", email: "nuevo@test.com", telefono: "99998888" } }
    end
  end

  test "y sin correo no se encola nada" do
    entrar users(:admin)

    assert_no_enqueued_emails do
      post clientes_url, params: { cliente: { sucursal_retiro_id: sucursales(:humuya_tgu).id, nombre: "Sin",
                                              apellido: "Correo De Prueba", telefono: "99998888" } }
    end
    assert_equal "Sin", Cliente.last.nombre
  end

  test "la gemela: registrarse en el portal tambien manda la bienvenida" do
    assert_enqueued_emails 1 do
      post registro_url, params: { cliente: { sucursal_retiro_id: sucursales(:humuya_tgu).id, nombre: "Test",
                                              apellido: "User Prueba", email: "newclient@test.com", telefono: "99990000",
                                              password: "Secure123!", password_confirmation: "Secure123!" } }
    end
  end

  test "el boton de la ficha manda la informacion actualizada" do
    entrar users(:admin)
    get cliente_url(@cliente)
    assert_select "form[action=?] button", enviar_casillero_cliente_path(@cliente), text: /Enviar casillero/

    assert_enqueued_emails 1 do
      post enviar_casillero_cliente_url(@cliente)
    end
    assert_redirected_to cliente_url(@cliente)
    assert_match @cliente.email, flash[:notice]
  end

  test "sin correo el boton no aparece, y la accion lo dice" do
    entrar users(:admin)
    @cliente.update_columns(email: nil)

    get cliente_url(@cliente)
    assert_select "form[action=?]", enviar_casillero_cliente_path(@cliente), count: 0

    assert_no_enqueued_emails { post enviar_casillero_cliente_url(@cliente) }
    assert_equal "El cliente no tiene correo.", flash[:alert]
  end

  test "SAC le manda la informacion general a un correo cualquiera" do
    sac = User.create!(nombre: "Servicio Al Cliente", email_address: "sac@test.com", password: "password123",
                       rol: "sac", ubicacion: "honduras", activo: true)
    entrar sac
    get clientes_url
    assert_select "a[href=?]", informacion_casillero_clientes_path

    get informacion_casillero_clientes_url
    assert_response :success

    assert_enqueued_emails 1 do
      post informacion_casillero_clientes_url, params: { correo: " prospecto@example.com ", nombre: "Ana" }
    end
    assert_redirected_to informacion_casillero_clientes_path
    assert_match "prospecto@example.com", flash[:notice]
  end

  test "un correo que no es correo no se manda" do
    entrar users(:admin)

    assert_no_enqueued_emails do
      post informacion_casillero_clientes_url, params: { correo: "no-es-un-correo" }
    end
    assert_response :unprocessable_entity
  end

  test "el digitador de Miami no manda" do
    entrar users(:digitador)

    assert_no_enqueued_emails do
      post informacion_casillero_clientes_url, params: { correo: "alguien@example.com" }
      post enviar_casillero_cliente_url(@cliente)
    end
  end
end
