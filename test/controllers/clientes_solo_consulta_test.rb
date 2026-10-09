require "test_helper"

# C16-06 · Yusef, 2026-08-25, leyendo el bloque Miami del menú:
#
#   "Falta Clientes para Miami, para que ellos lo puedan ver."
#   "Recordá que Miami no va a poder ver todo… vamos a sectorizar las cosas.
#    Aquí van a tener restricciones de ver y de modificar, sobre todo."
#
# Hasta acá `can_access?(:clientes)` era `true` para todos y el controller no
# tenía guard de edición: el digitador creaba y editaba clientes. Jorge: solo el
# digitador queda en consulta; el supervisor de Miami sigue editando.
class ClientesSoloConsultaTest < ActionDispatch::IntegrationTest
  setup { @cliente = clientes(:juan) }

  # ── El digitador consulta ───────────────────────────────────────────────

  test "el digitador ve la lista y la ficha" do
    entrar users(:digitador)

    get clientes_url
    assert_response :success
    get cliente_url(@cliente)
    assert_response :success
  end

  test "pero no ve como crear ni como editar" do
    entrar users(:digitador)

    get clientes_url
    assert_no_match(/Nuevo Cliente/, response.body)
    assert_no_match(/data-shortcut="F7"/, response.body)

    get cliente_url(@cliente)
    assert_no_match(/>\s*Editar\s*</, response.body)
    assert_no_match(/data-shortcut="F6"/, response.body)
    assert_no_match(/#{clave_cliente_path(@cliente)}/, response.body, "el formulario de la clave es editar")
  end

  test "y si entra a la URL a mano, la lista lo devuelve con el porque" do
    entrar users(:digitador)

    get new_cliente_url
    assert_redirected_to clientes_path
    assert_match(/solo consulta/, flash[:alert])

    get edit_cliente_url(@cliente)
    assert_redirected_to clientes_path

    patch cliente_url(@cliente), params: { cliente: { telefono: "9999-9999" } }
    assert_redirected_to clientes_path
    assert_not_equal "9999-9999", @cliente.reload.telefono

    digest = @cliente.password_digest
    patch clave_cliente_url(@cliente), params: { cliente: { password: "secreta123", password_confirmation: "secreta123" } }
    assert_redirected_to clientes_path
    assert_equal digest, @cliente.reload.password_digest, "le cambió la clave"
  end

  # ── Los demás siguen editando ───────────────────────────────────────────

  test "el supervisor de Miami sigue editando" do
    users(:digitador).update!(rol: "supervisor_miami")
    entrar users(:digitador)

    get edit_cliente_url(@cliente)
    assert_response :success
    get cliente_url(@cliente)
    assert_match(/>\s*Editar\s*</, response.body)
  end

  test "y el cajero tambien, como hasta ahora" do
    entrar users(:cajero)

    get new_cliente_url
    assert_response :success
  end

  # ── Dónde está Clientes en el menú ──────────────────────────────────────

  test "para Miami, Clientes vive adentro de su bloque, una sola vez" do
    entrar users(:digitador)
    get clientes_url

    sidebar = response.body[/<aside id="sidebar".*?<\/aside>/m]
    assert sidebar, "no se encontró el sidebar"
    assert_equal 1, sidebar.scan(%r{href="#{clientes_path}"}).size, "Clientes tiene que estar una sola vez"
    assert_operator sidebar.index("Miami"), :<, sidebar.index(%(href="#{clientes_path}")),
                    "Clientes tiene que estar adentro del bloque Miami"
    assert_operator sidebar.index(%(href="#{clientes_path}")), :<, sidebar.index("Logistica")
  end

  test "para quien no tiene mostrador, sigue suelto como siempre" do
    entrar users(:cajero)
    get clientes_url

    sidebar = response.body[/<aside id="sidebar".*?<\/aside>/m]
    assert_equal 1, sidebar.scan(%r{href="#{clientes_path}"}).size
    assert_nil sidebar.index(">Miami<"), "el cajero no tiene bloque Miami"
  end

  # ── La búsqueda de la lista es la del autocomplete ─────────────────────

  test "buscar «10» pone a C10 primero, no enterrado" do
    # Yusef probó la lista con «1» y «10»; Jorge: "ese filtro no lo tengo así
    # como lo querés". Ordenaba por fecha de alta antes de buscar.
    c210 = Cliente.create!(codigo: "C210", nombre: "Dos", apellido: "Diez")
    c100 = Cliente.create!(codigo: "C100", nombre: "Cien", apellido: "Cliente")
    c10  = Cliente.create!(codigo: "C10",  nombre: "Diez", apellido: "Cliente")
    entrar users(:admin)

    get clientes_url, params: { q: "10" }
    assert_response :success

    posicion = ->(c) { response.body.index(%(href="#{cliente_path(c)}")) }
    assert posicion.call(c10), "C10 no salió"
    assert_operator posicion.call(c10), :<, posicion.call(c100), "C10 tiene que ir antes que C100"
    assert_operator posicion.call(c10), :<, posicion.call(c210)
  end

  private

  def entrar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
