require "test_helper"

# `RP-58` · La pantalla donde se mueve el mapa de permisos.
#
# Yusef: *"editar el título del rol y lo que ellos puedan y no puedan"*, porque
# si no *"te vamos a estar molestando con que necesitamos quitar y poner"*.
class PermisosTest < ActionDispatch::IntegrationTest
  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # ── Las dos garantías que no se pueden romper ───────────────────────────
  #
  # Sin éstas, la pantalla es un arma cargada: la primera deja que alguien se
  # quede sin sistema, la segunda que se regale permisos.

  test "una fila que le niega algo al admin no hace nada" do
    # No se puede ni guardar…
    fila = PermisoDeRol.new(rol: "admin", seccion: "etiquetar", permitido: false)
    assert_not fila.valid?, "el admin no lleva excepciones"

    # …y si alguien la mete por SQL, tampoco cambia nada: el cortocircuito
    # corre antes de mirar la tabla.
    PermisoDeRol.insert_all([ { rol: "admin", seccion: "etiquetar", permitido: false,
                                created_at: Time.current, updated_at: Time.current } ])
    ingresar(users(:admin))
    get etiquetar_url

    assert_response :success, "el admin entra siempre — si no, alguien puede dejarse afuera"
  end

  test "la pantalla de permisos y la de usuarios no se pueden conceder" do
    %w[permisos usuarios].each do |seccion|
      fila = PermisoDeRol.new(rol: "cajero", seccion: seccion, permitido: true)
      assert_not fila.valid?, "#{seccion} no se puede mover desde la pantalla"
    end
  end

  # ── Quién entra ────────────────────────────────────────────────────────

  test "solo el admin entra" do
    ingresar(users(:supervisor_miami))
    get permisos_url
    assert_redirected_to root_path
  end

  test "el admin ve la grilla, sin la columna de admin" do
    ingresar(users(:admin))
    get permisos_url

    assert_response :success
    assert_select "input[name=?]", "permisos[cajero][caja]"
    assert_select "input[name^=?]", "permisos[admin]", false,
                  "el admin no se dibuja: su acceso es cortocircuito, no una fila"
  end

  # ── Guardar solo lo que se movió ───────────────────────────────────────

  test "destildar algo que el código permite deja una excepción" do
    ingresar(users(:admin))
    assert PermisosDelSistema.politica("cajero", :caja), "el código se lo permite"

    patch permisos_url, params: { permisos: { "cajero" => grilla_de("cajero", sin: :caja) } }

    fila = PermisoDeRol.find_by(rol: "cajero", seccion: "caja")
    assert fila, "tiene que quedar la excepción"
    assert_not fila.permitido
  end

  test "y el cajero deja de entrar de verdad" do
    PermisoDeRol.create!(rol: "cajero", seccion: "caja", permitido: false)
    ingresar(users(:cajero))

    get caja_url

    assert_redirected_to root_path
  end

  test "volver a dejarlo como estaba borra la excepción, no guarda otra" do
    PermisoDeRol.create!(rol: "cajero", seccion: "caja", permitido: false)
    ingresar(users(:admin))

    patch permisos_url, params: { permisos: { "cajero" => { "caja" => "1" } } }

    assert_nil PermisoDeRol.find_by(rol: "cajero", seccion: "caja"),
               "coincidir con el código no deja fila: volver al default es borrar"
  end

  # Es la mitad del diseño: con cero filas el sistema se porta como antes de que
  # esta pantalla existiera.
  test "sin excepciones, manda el código" do
    assert_equal 0, PermisoDeRol.count

    ingresar(users(:cajero))
    get caja_url
    assert_response :success

    ingresar(users(:digitador))
    get caja_url
    assert_redirected_to root_path
  end

  test "conceder algo que el código niega también funciona" do
    assert_not PermisosDelSistema.politica("digitador_miami", :caja)
    PermisoDeRol.create!(rol: "digitador_miami", seccion: "caja", permitido: true)

    ingresar(users(:digitador))
    get caja_url

    assert_response :success
  end

  # ── Quién movió qué ────────────────────────────────────────────────────

  test "queda registrado quién lo cambió" do
    ingresar(users(:admin))

    assert_difference -> { PaperTrail::Version.where(item_type: "PermisoDeRol").count }, 1 do
      patch permisos_url, params: { permisos: { "cajero" => grilla_de("cajero", sin: :caja) } }
    end
  end

  # Sin el marcador de columna, un rol al que se le destilda todo llegaría igual
  # que un rol que no vino, y el servicio le borraría los accesos.
  test "un rol que no viene en el formulario no se toca" do
    ingresar(users(:admin))

    patch permisos_url, params: { permisos: { "cajero" => grilla_de("cajero") } }

    assert_equal 0, PermisoDeRol.where.not(rol: "cajero").count,
                 "los demás roles no se tocan si no vinieron"
  end

  test "destildar TODO un rol se lo niega, no lo ignora" do
    ingresar(users(:admin))

    patch permisos_url, params: { permisos: { "cajero" => { "_presente" => "1" } } }

    assert PermisoDeRol.where(rol: "cajero", permitido: false).any?,
           "vino y no marcó nada: eso es negar, no «no vino»"
    ingresar(users(:cajero))
    get caja_url
    assert_redirected_to root_path
  end

  # ── El bucle, que es lo que esta pantalla hace posible ─────────────────
  #
  # Apareció en el QA: quitarle Caja Diaria al cajero —lo primero que alguien va
  # a probar— dejaba `/` mandando a `/caja` y `/caja` devolviendo a `/`. El
  # navegador cortaba con ERR_TOO_MANY_REDIRECTS y el usuario quedaba sin puerta
  # de entrada y sin explicación.
  test "quitarle su sección de entrada a un rol no lo deja en un bucle" do
    PermisoDeRol.create!(rol: "cajero", seccion: "caja", permitido: false)
    ingresar(users(:cajero))

    get root_url

    # Va a la siguiente que sí puede abrir, no de vuelta a la que le negaron.
    assert_response :redirect
    assert_not_equal caja_url, response.location, "ahí es donde estaba el bucle"
    follow_redirect!
    assert_response :success
  end

  test "sin ninguna sección alcanzable se le explica, no se lo redirige" do
    %w[caja pre_facturas paquetes].each do |seccion|
      PermisoDeRol.create!(rol: "cajero", seccion: seccion, permitido: false)
    end
    ingresar(users(:cajero))

    get root_url

    assert_response :forbidden
    assert_match(/no tiene secciones habilitadas/i, response.body)
    assert_match(/Permisos por rol/, response.body, "le dice a quién pedírselo")
  end

  private

  # Lo que manda el formulario: el marcador de columna más una entrada por cada
  # casilla tildada.
  def grilla_de(rol, sin: nil)
    marcadas = SeccionesDelSistema::TODAS.keys.select do |seccion|
      next false unless PermisosDelSistema.editable?(seccion)
      next false if seccion == sin

      PermisosDelSistema.politica(rol, seccion)
    end
    marcadas.to_h { |s| [ s.to_s, "1" ] }.merge("_presente" => "1")
  end
end
