require "test_helper"

# C29-03 · La sucursal donde retira se pregunta al abrir el casillero, y la
# etiqueta nunca la inventa.
#
# Yusef, 2026-10-08, con la etiqueta de Sofía en pantalla —de Choluteca,
# retira en Humuya, y el campo «sin definir»—:
#
#   > "Aquí hay un error: dice San Pedro Sula y dice Humuya."
#   > "La ciudad donde es es una cosa y donde retira es otra."
#   > "Si va a retirar en Tegucigalpa, la sucursal de Tegucigalpa tiene que
#   >  irte. Aunque él sea de Choluteca."
#   > "Cuando ellos crean el casillero, vas a preguntar a dónde le gustaría
#   >  retirar su producto."
class SucursalDeRetiroObligatoriaTest < ActionDispatch::IntegrationTest
  include EtiquetaHelper

  setup do
    @tgu = sucursales(:humuya_tgu)
  end

  test "el admin no crea un cliente sin sucursal de retiro" do
    entrar_como :admin

    assert_no_difference("Cliente.count") do
      post clientes_url, params: { cliente: { nombre: "Sofía Elena", apellido: "Mejía Ruiz", ciudad: "Choluteca" } }
    end
    assert_response :unprocessable_entity
    assert_match "hay que elegir dónde va a retirar", response.body
  end

  test "con la sucursal elegida, sí" do
    entrar_como :admin

    assert_difference("Cliente.count") do
      post clientes_url, params: { cliente: { nombre: "Sofía Elena", apellido: "Mejía Ruiz",
                                              ciudad: "Choluteca", sucursal_retiro_id: @tgu.id } }
    end
    assert_equal @tgu, Cliente.order(:id).last.sucursal_retiro
  end

  test "el cliente viejo sin sucursal se sigue pudiendo editar" do
    # Los importados del sistema viejo no la traen. Corregirle el teléfono no
    # puede trabarse por un campo que nadie tocó.
    cliente = clientes(:juan)
    cliente.update!(sucursal_retiro: nil)
    entrar_como :admin

    patch cliente_url(cliente), params: { cliente: { telefono: "9999-1234", sucursal_retiro_id: "" } }

    assert_equal "9999-1234", cliente.reload.telefono
  end

  test "pero la que tenía no se puede vaciar" do
    cliente = clientes(:juan)
    cliente.update!(sucursal_retiro: @tgu)
    entrar_como :admin

    patch cliente_url(cliente), params: { cliente: { sucursal_retiro_id: "" } }

    assert_response :unprocessable_entity
    assert_equal @tgu, cliente.reload.sucursal_retiro
  end

  test "el registro del portal la pregunta" do
    # La gemela de `/clientes#create`: acá el que abre el casillero es el
    # cliente mismo.
    get new_registro_url
    assert_select "select[name='cliente[sucursal_retiro_id]'][required]"
    assert_select "select[name='cliente[sucursal_retiro_id]'] option", text: @tgu.nombre

    assert_no_difference("Cliente.count") do
      post registro_url, params: { cliente: registro.except(:sucursal_retiro_id) }
    end
    assert_response :unprocessable_entity

    assert_difference("Cliente.count") do
      post registro_url, params: { cliente: registro }
    end
    assert_equal @tgu, Cliente.find_by(email: "sofia.c29@test.com").sucursal_retiro
  end

  test "la etiqueta del paquete sin sucursal dice que falta, no la de por defecto" do
    # La caía a la sucursal de retiro por defecto (SPS): una caja que dice SPS
    # se empaca con las de SPS. Una que dice SIN SUCURSAL se aparta.
    entrar_como :digitador
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update_columns(sucursal_id: nil)
    paquete.cliente.update_columns(ciudad: "Choluteca")

    get etiqueta_paquete_url(paquete)

    sucursal = response.body[/data-campo="sucursal"[^>]*>(.*?)</m, 1].to_s.strip
    assert_equal EtiquetaHelper::SIN_SUCURSAL, sucursal
    assert_no_match(/Choluteca/, sucursal)
  end

  test "la etiqueta con sucursal la sigue diciendo" do
    entrar_como :digitador
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update_columns(sucursal_id: @tgu.id)

    get etiqueta_paquete_url(paquete)

    assert_equal @tgu.nombre, response.body[/data-campo="sucursal"[^>]*>(.*?)</m, 1].to_s.strip
  end

  private

  def entrar_como(usuario)
    post session_url, params: { email_address: users(usuario).email_address, password: "password123" }
  end

  def registro
    { nombre: "Sofía Elena", apellido: "Mejía Ruiz", email: "sofia.c29@test.com", telefono: "99990000",
      sucursal_retiro_id: @tgu.id, password: "Secure123!", password_confirmation: "Secure123!" }
  end
end
