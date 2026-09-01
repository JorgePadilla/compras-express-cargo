require "test_helper"

# `RP-58` paso 2b · El título del rol, editable.
#
# Yusef: *"editar el título del rol y lo que ellos puedan y no puedan"*. Lo
# segundo lo resolvió el paso 1; esto es lo primero.
#
# Las dos cosas que este test cuida son las dos que se rompen solas:
#
#   1. **Que el nombre nuevo llegue a todas partes.** Si una pantalla esquiva
#      `User.titulo_de_rol`, renombrar deja media aplicación diciendo el nombre
#      viejo — y nadie se entera hasta que alguien pregunta cuál es el bueno.
#   2. **Que renombrar no cambie nada más.** El título es cómo se lee; los
#      permisos, el PIN y las colas siguen atados al **código** del rol.
class TituloDelRolEditableTest < ActionDispatch::IntegrationTest
  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def renombrar(rol, titulo, descripcion: "Lo que sea")
    TituloDeRol.create!(rol: rol, titulo: titulo, descripcion: descripcion)
    Current.titulos = nil
  end

  # ── Que el nombre nuevo llegue a todas partes ───────────────────────────

  test "renombrar un puesto se ve en todas las pantallas que lo muestran" do
    renombrar("cajero", "Sub-Jefa de Caja")
    ingresar(users(:admin))

    # El listado de usuarios y la ficha.
    get users_url
    assert_select "body", text: /Sub-Jefa de Caja/

    get user_url(users(:cajero))
    assert_select "body", text: /Sub-Jefa de Caja/

    # El encabezado de columna de /permisos, que antes mostraba el código crudo.
    get permisos_url
    assert_select "body", text: /Sub-Jefa de Caja/
    assert_select "body", { text: /supervisor caja/, count: 0 },
                  "la pantalla seguía mostrando códigos con guiones bajos"

    # El dropdown del formulario de usuario.
    get edit_user_url(users(:cajero))
    assert_select "body", text: /Sub-Jefa de Caja/
  end

  test "el dropdown sigue mandando el código, no el título" do
    renombrar("cajero", "Sub-Jefa de Caja")

    opciones = User.rol_options_for_select.to_h
    assert_equal "cajero", opciones["Sub-Jefa de Caja — Lo que sea"],
                 "el value tiene que seguir siendo el código: es lo que el form manda"

    # Y de punta a punta: se guarda por código aunque en pantalla se lea otra cosa.
    ingresar(users(:admin))
    patch user_url(users(:digitador)), params: { user: { rol: "cajero" } }

    assert_equal "cajero", users(:digitador).reload.rol
  end

  # ── Que renombrar no cambie nada más ────────────────────────────────────

  test "renombrar no toca lo que el puesto puede hacer" do
    antes = PermisosDelSistema.politica("cajero", :caja)
    renombrar("cajero", "Cualquier Otra Cosa")

    assert_equal antes, PermisosDelSistema.politica("cajero", :caja),
                 "la política se resuelve por código: el título no la puede mover"

    ingresar(users(:cajero))
    get caja_url
    assert_response :success, "el cajero perdió su pantalla porque le cambiaron el nombre"
  end

  test "renombrar no toca quién autoriza" do
    u = users(:supervisor_prefactura)
    u.update!(pin: "4321", pin_confirmation: "4321")
    renombrar("supervisor_prefactura", "Jefatura de Pre-Factura")

    assert u.reload.puede_autorizar?
    assert_includes User.autorizantes, u
    assert_equal "Jefatura de Pre-Factura", u.rol_label, "pero sí cambia cómo se lee"
  end

  # ── La bitácora ─────────────────────────────────────────────────────────

  test "una versión vieja se lee con el nombre de hoy" do
    # `paper_trail` guarda **códigos**, así que un registro de antes del cambio
    # de nombre no queda hablando de un puesto que ya nadie reconoce.
    renombrar("cajero", "Sub-Jefa de Caja")

    assert_equal "Sub-Jefa de Caja", User.titulo_de_rol("cajero")
  end

  test "un rol que el código no describe cae en el humanize" do
    assert_equal "Cajero", User.titulo_de_rol("cajero")
    assert_equal "Inventado", User.titulo_de_rol("inventado")
  end

  # ── La pantalla ─────────────────────────────────────────────────────────

  # Se sigue el redirect en vez de limpiar `Current.titulos` a mano, para recorrer
  # el mismo camino que hace la persona: guardar, volver a la pantalla, y leer
  # ahí el nombre nuevo.
  #
  # Ojo con lo que este test **no** prueba: probado al revés, pasa igual sin el
  # `Current.titulos = nil` de `TituloDeRol.guardar`, porque el límite de request
  # ya resetea `CurrentAttributes`. Esa línea es defensa por si algún día
  # `update` renderiza en vez de redirigir; no es lo que sostiene esto.
  test "guardar renombra, y vaciar el campo vuelve al nombre del sistema" do
    ingresar(users(:admin))

    patch roles_url, params: { roles: { "cajero" => { titulo: "Sub-Jefa de Caja",
                                                      descripcion: "Cobra y factura" } } }
    follow_redirect!
    assert_select "input[name=?][value=?]", "roles[cajero][titulo]", "Sub-Jefa de Caja"

    # Vaciar el campo borra la fila: es el «volver al del sistema».
    patch roles_url, params: { roles: { "cajero" => { titulo: "", descripcion: "" } } }
    follow_redirect!
    assert_select "input[name=?][value=?]", "roles[cajero][titulo]", "Cajero"
    assert_nil TituloDeRol.find_by(rol: "cajero"), "la fila tenía que irse, no quedarse vacía"
  end

  # Vaciar el título borra la fila entera, y con ella la descripción. Va escrito
  # como decisión y no como accidente: el título es la razón de ser de la fila —
  # una descripción sola, colgando de un rol que se llama como el sistema lo
  # llama, no es una excepción de nada.
  test "vaciar el título se lleva también la descripción" do
    ingresar(users(:admin))
    renombrar("cajero", "Sub-Jefa de Caja", descripcion: "Cobra y factura")

    patch roles_url, params: { roles: { "cajero" => { titulo: "",
                                                      descripcion: "Cobra y factura" } } }
    follow_redirect!

    assert_nil TituloDeRol.find_by(rol: "cajero")
    assert_equal "Cajero", User.titulo_de_rol("cajero")
    assert_equal User.descripcion_del_sistema("cajero"), User.descripcion_de_rol("cajero")
  end

  test "un título igual al del sistema no deja fila" do
    ingresar(users(:admin))

    patch roles_url, params: { roles: { "cajero" => {
      titulo: User.titulo_del_sistema("cajero"),
      descripcion: User.descripcion_del_sistema("cajero")
    } } }

    assert_nil TituloDeRol.find_by(rol: "cajero"),
               "guardar el mismo nombre del código no puede dejar una fila que lo tape"
  end

  test "el admin también se puede renombrar" do
    # Al revés que en /permisos, donde no aparece: allá es porque no se le pueden
    # quitar accesos. Cómo se lee su puesto sí es suyo.
    ingresar(users(:admin))
    patch roles_url, params: { roles: { "admin" => { titulo: "Gerencia", descripcion: "" } } }
    follow_redirect!

    assert_select "input[name=?][value=?]", "roles[admin][titulo]", "Gerencia"
  end

  test "los roles no se crean ni se borran desde acá" do
    # No hay puerta: el controller no tiene esas acciones. Un rol nuevo desde una
    # pantalla quedaría fuera del enum, del `case` de `politica` y de cada
    # constante `*_ROLES` — o sea, un rol que ninguna regla del sistema conoce.
    %w[new create destroy].each do |accion|
      assert_not_includes RolesController.action_methods, accion,
                          "los roles no se crean ni se borran: sus códigos viven en el código"
    end

    # Y un código inventado no se puede guardar ni por el modelo.
    assert_not TituloDeRol.new(rol: "jefe_supremo", titulo: "Jefe").valid?
  end

  test "solo el admin entra" do
    ingresar(users(:cajero))
    get roles_url

    assert_redirected_to root_path
  end

  # ── Sin filas, todo igual que antes ─────────────────────────────────────

  test "con la tabla vacía se comporta como antes de que existiera" do
    assert_equal 0, TituloDeRol.count

    User.rols.keys.each do |rol|
      assert_equal User.titulo_del_sistema(rol), User.titulo_de_rol(rol)
    end
  end
end
