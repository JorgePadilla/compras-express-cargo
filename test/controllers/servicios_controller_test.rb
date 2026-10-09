require "test_helper"

# PR-10.a: "la tabla de servicios" que Yusef pedía. Antes los precios se
# sembraban a mano y no había pantalla para tocarlos.
class ServiciosControllerTest < ActionDispatch::IntegrationTest
  setup { login_as users(:admin) }

  def login_as(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "index agrupa las tarifas por servicio" do
    get servicios_url

    assert_response :success
    assert_match "Tabla de Servicios", response.body
    assert_match "CER", response.body
  end

  # PR-10.g: con los precios reales son ~60 filas. El orden por id dejaba el
  # precio público hasta abajo de cada servicio (los NULL ordenan al final en
  # Postgres), que es justo lo primero que uno busca.
  test "index muestra el precio de lista antes que las excepciones" do
    TarifasPropuesta2026.sembrar!

    get servicios_url

    assert_response :success
    assert_operator response.body.index("Público"), :<, response.body.index("Clientes Amigos"),
                    "el precio público tiene que salir arriba de las categorías"
  end

  test "crea una tarifa convirtiendo el minimo con ISV al neto" do
    assert_difference("Tarifa.count") do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id,
        precio_libra: 4.50, moneda: "USD",
        desde_libras: 0,
        minimo_monto_con_isv: 200.00, minimo_moneda: "LPS",
        aplica_minimo: "1", activo: "1"
      } }
    end

    t = Tarifa.order(:id).last
    assert_equal BigDecimal("173.91"), t.minimo_monto,
                 "Yusef escribe 200 (con ISV) y la columna guarda el neto"
    assert_equal BigDecimal("200.00"), t.minimo_monto_con_isv
    assert_redirected_to servicios_path
  end

  test "crea una tarifa de media libra sin minimo — el caso Exchange" do
    post servicios_url, params: { tarifa: {
      tipo_envio_id: tipo_envios(:cer).id, precio_libra: 4.00, moneda: "USD",
      desde_libras: 0, aplica_minimo: "0", incremento_libras: "0.5", activo: "1"
    } }

    t = Tarifa.order(:id).last
    assert_not t.aplica_minimo
    assert_equal BigDecimal("0.5"), t.incremento_libras
  end

  test "rechaza un escalon invertido" do
    assert_no_difference("Tarifa.count") do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 1, moneda: "USD",
        desde_libras: 10, hasta_libras: 5, activo: "1"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "actualiza y elimina" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")

    patch servicio_url(t), params: { tarifa: { precio_libra: 5.25 } }
    assert_equal BigDecimal("5.25"), t.reload.precio_libra

    assert_difference("Tarifa.count", -1) { delete servicio_url(t) }
  end

  test "solo admin entra" do
    login_as users(:cajero)

    get servicios_url

    assert_redirected_to root_path
  end

  # ── PR-C7.12 · los grupos de clientes se administran acá ──
  #
  # La pantalla aparte se fue, así que este formulario pasó a ser la única forma
  # de crear un grupo. Se teclea el nombre y si no existe se crea, igual que el
  # carrier de /etiquetar que Yusef aprobó.

  test "escribir un grupo que no existe lo crea y se lo asigna a la tarifa" do
    assert_difference [ "Tarifa.count", "CategoriaPrecio.count" ], 1 do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 3.25, moneda: "USD",
        desde_libras: 0, activo: "1", categoria_nombre: "Mayoristas Nuevos"
      } }
    end

    assert_equal "Mayoristas Nuevos", Tarifa.order(:id).last.categoria_precio.nombre
  end

  test "un grupo que ya existe se reusa, sin importar mayusculas" do
    existente = categoria_precios(:regular)

    assert_no_difference "CategoriaPrecio.count" do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 3.25, moneda: "USD",
        desde_libras: 0, activo: "1", categoria_nombre: existente.nombre.upcase
      } }
    end

    assert_equal existente, Tarifa.order(:id).last.categoria_precio
  end

  # Sin la transacción, un grupo tecleado en una tarifa que no pasa validación
  # quedaba creado y huérfano — y encima invisible, porque ya no hay pantalla
  # donde verlo.
  test "si la tarifa no pasa validacion el grupo nuevo tampoco queda" do
    assert_no_difference [ "Tarifa.count", "CategoriaPrecio.count" ] do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 1, moneda: "USD",
        desde_libras: 10, hasta_libras: 5, activo: "1",
        categoria_nombre: "Grupo Fantasma"
      } }
    end

    assert_response :unprocessable_entity
    assert_nil CategoriaPrecio.find_by(nombre: "Grupo Fantasma")
  end

  test "dejar el grupo en blanco se lo quita a la tarifa" do
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                       categoria_precio: categoria_precios(:regular))

    patch servicio_url(t), params: { tarifa: { categoria_nombre: "" } }

    assert_nil t.reload.categoria_precio_id
  end

  # ── PR-C7.14 · el precio especial se elige por código ──
  #
  # Jorge: "¿se puede hacer lista que sea por código, porque en el sistema no
  # usamos ID?". Era un `number_field :cliente_id`: había que saber que
  # "CEC-001" es internamente el 47.
  #
  # Manda **lo que se ve**, no el id oculto. `BusquedaAutocomplete` solo escribe
  # ese campo, nunca lo limpia, así que confiar en él dejaba tarifas pegadas a un
  # cliente después de que alguien borrara el texto para quitárselo.

  test "se puede elegir el cliente tecleando su codigo, sin saber el id" do
    juan = clientes(:juan)

    post servicios_url, params: { tarifa: {
      tipo_envio_id: tipo_envios(:cer).id, precio_libra: 2.75, moneda: "USD",
      desde_libras: 0, activo: "1", cliente_busqueda: juan.codigo
    } }

    assert_equal juan, Tarifa.order(:id).last.cliente
  end

  test "el codigo no distingue mayusculas" do
    juan = clientes(:juan)

    post servicios_url, params: { tarifa: {
      tipo_envio_id: tipo_envios(:cer).id, precio_libra: 2.75, moneda: "USD",
      desde_libras: 0, activo: "1", cliente_busqueda: juan.codigo.downcase
    } }

    assert_equal juan, Tarifa.order(:id).last.cliente
  end

  # El autocomplete deja "CÓDIGO — Nombre" en el campo; el primer token es el
  # código y el resto es para que el operario lea a quién eligió.
  test "acepta el CODIGO — Nombre que deja el autocomplete" do
    juan = clientes(:juan)

    post servicios_url, params: { tarifa: {
      tipo_envio_id: tipo_envios(:cer).id, precio_libra: 2.75, moneda: "USD",
      desde_libras: 0, activo: "1",
      cliente_busqueda: "#{juan.codigo} — #{juan.nombre_completo}",
      cliente_id: juan.id
    } }

    assert_equal juan, Tarifa.order(:id).last.cliente
  end

  # El bug que el cambio destapó: borrar el texto tiene que **quitar** el precio
  # especial, y el id oculto viejo no puede ganarle.
  test "vaciar el campo le quita el precio especial a la tarifa" do
    juan = clientes(:juan)
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 2.75, moneda: "USD",
                       cliente: juan)

    patch servicio_url(t), params: { tarifa: { cliente_busqueda: "", cliente_id: juan.id } }

    assert_nil t.reload.cliente_id,
               "el id oculto se quedó con el valor viejo: la tarifa sigue siendo de ese cliente"
  end

  # Un nil silencioso convertiría un typo en una tarifa de precio de lista, que
  # cobra distinto sin que nadie se entere.
  test "un codigo que no existe no guarda y dice cual era" do
    assert_no_difference "Tarifa.count" do
      post servicios_url, params: { tarifa: {
        tipo_envio_id: tipo_envios(:cer).id, precio_libra: 2.75, moneda: "USD",
        desde_libras: 0, activo: "1", cliente_busqueda: "CEC-999"
      } }
    end

    assert_response :unprocessable_entity
    assert_match(/CEC-999/, response.body)
  end

  test "el formulario de edicion llega con el codigo y el nombre, no con el id" do
    juan = clientes(:juan)
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 2.75, moneda: "USD",
                       cliente: juan)

    get edit_servicio_url(t)

    assert_response :success
    assert_match(/#{Regexp.escape("#{juan.codigo} — #{juan.nombre_completo}")}/, response.body)
    assert_no_match(/cliente puntual \(ID\)/, response.body)
  end

  # Guardar sin tocar el campo tiene que dejar la tarifa igual: el valor que
  # repinta el formulario es el mismo que el resolvedor sabe leer.
  test "abrir y guardar sin tocar nada no le cambia el cliente" do
    juan = clientes(:juan)
    t = Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 2.75, moneda: "USD",
                       cliente: juan)

    patch servicio_url(t), params: { tarifa: {
      cliente_busqueda: t.cliente_busqueda, cliente_id: juan.id, precio_libra: 3.00
    } }

    assert_equal juan, t.reload.cliente
    assert_equal BigDecimal("3.00"), t.precio_libra
  end

  test "el listado administra los grupos y ya no manda a una pantalla aparte" do
    get servicios_url

    assert_response :success
    assert_match(/Grupos de clientes/i, response.body)
    assert_no_match(%r{href="/categorias-precio"}, response.body,
                    "el listado de grupos dejó de ser una pantalla")
  end
end
