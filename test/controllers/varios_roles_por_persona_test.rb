require "test_helper"

# `RP-58` paso 2a · Una persona puede tener varios roles.
#
# Yusef, 2026-08-30, nombrando a dos personas que el enum de un solo rol no sabe
# describir: Michelle es *"Sub-Jefa de área de Caja y SAC"* y Bessy
# *"Supervisora de Caja y SAC"*. Antes cada combinación obligaba a inventar un
# rol nuevo, y con él una columna más en la matriz de permisos.
#
# **Los roles suman.** Y el par que se usa acá lo prueba de las dos direcciones:
# `digitador_miami` abre `:etiquetar` y no `:caja`; `cajero` abre `:caja` y no
# `:etiquetar`. Quien tenga los dos tiene que entrar a los dos.
class VariosRolesPorPersonaTest < ActionDispatch::IntegrationTest
  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  # Digitador de Miami que además hace caja.
  def con_dos_roles
    @con_dos_roles ||= begin
      u = users(:digitador)
      u.roles_adicionales.create!(rol: "cajero")
      u.reload
    end
  end

  # `can_access?` sin pasar por HTTP: contesta la pregunta exacta de la
  # resolución sin depender de cómo esté trabada cada pantalla. Es la misma
  # sonda que ya usa `permisos_en_una_sola_fuente_test`.
  def puede?(user, seccion)
    sonda = ApplicationController.new
    Current.session = Struct.new(:user).new(user)
    Current.permisos = nil
    sonda.send(:can_access?, seccion)
  ensure
    Current.session = nil
    Current.permisos = nil
  end

  # ── El caso que lo motivó ───────────────────────────────────────────────

  test "con dos roles entra a lo de los dos" do
    assert_equal %w[digitador_miami cajero], con_dos_roles.roles

    ingresar(con_dos_roles)

    get etiquetar_url
    assert_response :success, "perdió lo que ya tenía por su rol principal"

    # Sin sumar, esto redirigía: el digitador no tiene caja.
    get caja_url
    assert_response :success, "el segundo rol no le abrió lo suyo"
  end

  # ── El bug silencioso: cómo se resuelven las excepciones ────────────────
  #
  # Sale solo si uno junta las excepciones de todos los roles en un mapa y
  # resuelve una vez: ahí la excepción puesta pensando en un rol le pisa al otro
  # un permiso que nadie le quitó.

  test "una excepción contra un rol no le quita lo que el otro rol le da" do
    # Alguien le quita Etiquetar a los digitadores. Pero esta persona también es
    # cajera… y el cajero no tiene etiquetar por el código, así que acá la
    # excepción sí tiene que morder.
    PermisoDeRol.create!(rol: "digitador_miami", seccion: "etiquetar", permitido: false)
    assert_not puede?(con_dos_roles, :etiquetar),
               "ningún rol suyo se la salva: la excepción tiene que morder"

    # Y al revés: le quitan Caja al cajero. Como digitadora tampoco la tiene, se
    # va igual. Las dos direcciones del mismo mecanismo.
    PermisoDeRol.create!(rol: "cajero", seccion: "caja", permitido: false)
    assert_not puede?(con_dos_roles, :caja)
  end

  test "la excepción de un rol no pisa lo que el código le da al otro" do
    # El caso que importa, y el que un mapa aplanado se come: se le niega
    # `:caja` al **digitador** —un rol que no la tenía—, y eso no puede quitarle
    # lo que su rol de cajera sí le da.
    PermisoDeRol.create!(rol: "digitador_miami", seccion: "caja", permitido: false)

    assert puede?(con_dos_roles, :caja),
           "la excepción de un rol le pisó al otro un permiso que nadie le quitó"
  end

  # Lo mismo que arriba pero **por HTTP**, y no es redundante: la sonda reinicia
  # `Current.permisos` a mano, así que nunca toca la memoización —una consulta
  # por request para las ~100 llamadas a `can_access?` de una página—. Este test
  # es el que prueba que el mapa memoizado trae las filas de **los dos** roles.
  test "por HTTP, la excepción de un rol tampoco pisa lo del otro" do
    PermisoDeRol.create!(rol: "digitador_miami", seccion: "caja", permitido: false)

    ingresar(con_dos_roles)
    get caja_url

    assert_response :success,
                    "el mapa memoizado se quedó con las filas de un solo rol"
  end

  test "una excepción que concede alcanza con que la tenga un solo rol" do
    # Al revés: conceder por excepción a uno de sus roles le abre la sección,
    # aunque el otro rol siga sin tenerla.
    PermisoDeRol.create!(rol: "cajero", seccion: "manifiestos", permitido: true)

    assert puede?(con_dos_roles, :manifiestos)
  end

  # ── Las reglas del rol adicional ────────────────────────────────────────

  test "admin no puede ser un rol adicional" do
    fila = RolDeUsuario.new(user: users(:cajero), rol: "admin")

    assert_not fila.valid?,
               "el cortocircuito pregunta por el rol principal: habría dos verdades a la vez"
  end

  test "el rol adicional no repite el principal ni se repite a sí mismo" do
    assert_not RolDeUsuario.new(user: users(:cajero), rol: "cajero").valid?

    con_dos_roles
    assert_not RolDeUsuario.new(user: con_dos_roles, rol: "cajero").valid?
  end

  # ── Lo que se movió con la suma ─────────────────────────────────────────

  test "ve la cola de tareas de sus dos áreas" do
    deptos = Tarea::DEPARTAMENTOS_POR_ROL
             .values_at(*con_dos_roles.roles).flatten.uniq

    assert_includes deptos, "miami", "perdió su propia cola"
    assert_includes deptos, "caja", "no ve la cola del segundo rol"

    sql = Tarea.visibles_para(con_dos_roles).to_sql
    assert_includes sql, "caja", "el scope no llegó a filtrar por el área del segundo rol"
  end

  test "ve las notas permanentes de sus dos áreas" do
    campos = con_dos_roles.notas_permanentes_visibles.map { |n| n[:campo] }

    assert_includes campos, :notas_miami
    assert_includes campos, :notas_caja,
                    "notas y tareas se filtran igual: si una suma y la otra no, se contradicen"
  end

  test "autoriza por su segundo rol, y aparece en la lista de quién autoriza" do
    u = users(:digitador)
    u.update!(pin: "4321", pin_confirmation: "4321")
    u.roles_adicionales.create!(rol: "supervisor_sac")

    assert u.reload.puede_autorizar?, "autoriza por su segundo rol"
    assert_includes User.autorizantes, u,
                    "y tiene que salir en el dropdown: si no, hay dos respuestas a la misma pregunta"
  end

  # ── El formulario ───────────────────────────────────────────────────────

  test "el admin se los asigna y se los quita desde la ficha del usuario" do
    ingresar(users(:admin))
    u = users(:digitador)

    patch user_url(u), params: { user: { roles_adicionales_lista: [ "cajero" ] } }
    assert_equal %w[digitador_miami cajero], u.reload.roles

    # Destildar **todas** las casillas tiene que quitarlos. Sin el hidden vacío
    # del formulario esto no manda nada y los roles se quedan puestos — es el
    # mismo agujero que `PR-388` ya tuvo que tapar acá al lado.
    patch user_url(u), params: { user: { roles_adicionales_lista: [ "" ] } }
    assert_equal %w[digitador_miami], u.reload.roles, "destildar todo no se los quitó"
  end

  # ── Sin roles adicionales, nada cambió ──────────────────────────────────

  test "quien tiene un solo rol se comporta igual que antes" do
    solo = users(:digitador)

    assert_equal [ solo.rol ], solo.roles
    assert puede?(solo, :etiquetar)
    assert_not puede?(solo, :caja)

    ingresar(solo)
    get permisos_url
    assert_redirected_to root_path
  end

  test "el admin sigue entrando a todo por el cortocircuito" do
    assert puede?(users(:admin), :permisos)
    assert puede?(users(:admin), :caja)
  end
end
