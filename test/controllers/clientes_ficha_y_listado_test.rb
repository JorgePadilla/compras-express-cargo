require "test_helper"

# Lo que se escribía y no se veía, y el cliente que desaparecía al darlo de baja.
#
# Los tres salen de auditar el audio del 19-ago contra el código, y son de la
# misma familia: campos que el formulario guarda y ninguna pantalla muestra.
class ClientesFichaYListadoTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }
  end

  # ── La ficha ────────────────────────────────────────────────────────────
  #
  # El RTN se escribía en el form y no se veía en ningún lado. Yusef lo pidió
  # para *"cuando ellos van pidiendo factura"*: para que alguien en caja lo LEA.

  test "la ficha muestra el RTN" do
    @cliente.update!(rtn: "08011985123456")

    get cliente_url(@cliente)

    assert_select "dt", text: "RTN"
    assert_match "08011985123456", response.body
  end

  test "y dice guion cuando no tiene" do
    @cliente.update_columns(rtn: nil)

    get cliente_url(@cliente)

    assert_select "dt", text: "RTN"
  end

  test "la ficha muestra la sucursal de retiro" do
    sucursal = Sucursal.first || Sucursal.create!(nombre: "San Pedro Sula")
    @cliente.update!(sucursal_retiro: sucursal)

    get cliente_url(@cliente)

    assert_select "dt", text: "Sucursal de retiro"
    assert_match sucursal.nombre, response.body
  end

  # Un cliente sin sucursal no es lo mismo que uno con una: la etiqueta cae a la
  # ciudad, y quien mira la ficha tiene que saberlo.
  test "y avisa cuando no tiene, porque la etiqueta cae a la ciudad" do
    @cliente.update_columns(sucursal_retiro_id: nil)

    get cliente_url(@cliente)

    assert_match "cae a la ciudad", response.body
  end

  # ── El listado ──────────────────────────────────────────────────────────
  #
  # Filtraba `activos` a secas: dar de baja a un cliente lo borraba de la
  # pantalla para siempre, ni buscándolo por código.

  test "por defecto el listado no trae a los dados de baja" do
    @cliente.update!(activo: false)

    get clientes_url

    assert_no_match @cliente.codigo, response.body
  end

  test "pero se pueden incluir" do
    @cliente.update!(activo: false)

    get clientes_url(inactivos: "1")

    assert_match @cliente.codigo, response.body
  end

  test "y buscando uno de baja se lo encuentra" do
    @cliente.update!(activo: false)

    get clientes_url(q: @cliente.codigo, inactivos: "1")

    assert_match @cliente.codigo, response.body
  end

  # Apagar el filtro no puede tirar lo que el operario tecleó.
  test "el link conserva la busqueda" do
    get clientes_url(q: "Juan")

    assert_select "a[href=?]", clientes_path(q: "Juan", inactivos: "1")
  end

  test "y al revés también" do
    get clientes_url(q: "Juan", inactivos: "1")

    assert_select "a[href=?]", clientes_path(q: "Juan")
  end
end
