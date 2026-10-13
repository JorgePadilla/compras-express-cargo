require "test_helper"

# C31-11 · El CRUD de feriados. Yusef: *"una vez ya quedan grabados. Bueno, se
# pueden modificar… porque cambian la semana morazánica, la semana santa"*, y
# *"elimina el feriado y lo agrega"*.
class FeriadosControllerTest < ActionDispatch::IntegrationTest
  setup { ingresar(users(:admin)) }

  test "el índice separa los próximos de los pasados" do
    Feriado.create!(fecha: Time.zone.today + 10, nombre: "Feriado que viene")
    Feriado.create!(fecha: Time.zone.today - 10, nombre: "Feriado que pasó")

    get feriados_path

    assert_response :success
    assert_select "h2", text: "Próximos"
    assert_select "h2", text: "Pasados"
    assert_match "Feriado que viene", response.body
    assert_operator response.body.index("Feriado que viene"), :<, response.body.index("Feriado que pasó")
  end

  test "sin feriados se ve el estado vacío" do
    Feriado.delete_all

    get feriados_path

    assert_response :success
    assert_match "No hay feriados cargados", response.body
  end

  test "el formulario usa el date picker del proyecto" do
    get new_feriado_path

    assert_response :success
    assert_select "input[name='feriado[fecha]'][data-controller='flatpickr']"
  end

  test "se agrega, se cambia y se borra" do
    assert_difference("Feriado.count", 1) do
      post feriados_path, params: { feriado: { fecha: "2026-10-21", nombre: "Semana Morazánica" } }
    end
    assert_redirected_to feriados_path
    feriado = Feriado.last
    assert_equal Date.new(2026, 10, 21), feriado.fecha

    patch feriado_path(feriado), params: { feriado: { fecha: "2026-10-22" } }
    assert_redirected_to feriados_path
    assert_equal Date.new(2026, 10, 22), feriado.reload.fecha

    assert_difference("Feriado.count", -1) { delete feriado_path(feriado) }
    assert_redirected_to feriados_path
  end

  test "la misma fecha no se carga dos veces" do
    Feriado.create!(fecha: Date.new(2026, 12, 25), nombre: "Navidad")

    assert_no_difference("Feriado.count") do
      post feriados_path, params: { feriado: { fecha: "2026-12-25", nombre: "Otra vez" } }
    end
    assert_response :unprocessable_entity
  end

  test "es de Configuración: quien no es admin no entra" do
    ingresar(users(:digitador))

    get feriados_path
    assert_redirected_to root_path

    assert_no_difference("Feriado.count") do
      post feriados_path, params: { feriado: { fecha: "2026-12-25", nombre: "Navidad" } }
    end
  end

  private

  def ingresar(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
