require "test_helper"

# `RP-58` · **Toda regla de rol pasa por `can_access?` o por una constante con
# nombre.** Ninguna se escribe suelta en un controller.
#
# Yusef avisó que el mapa de permisos se va a mover seguido —*"te vamos a estar
# molestando con que necesitamos quitar y poner… y te vamos a tener en ese
# relajo"*— y pidió poder moverlo él: *"editar el título del rol y lo que ellos
# puedan y no puedan"*.
#
# El paso previo a cualquier pantalla de permisos es éste: mientras haya reglas
# escritas a mano, **la pantalla miente** — diría que un rol puede algo que el
# controller le va a negar. Eran 27 repartidas: 15 `require_admin` y 12 listas
# de roles reescritas, seis de ellas repitiendo a mano una lista que ya tenía
# nombre.
#
# ── Las dos clases, que no son lo mismo ──────────────────────────────────
#
# **De sección** — «¿entrás a esta pantalla?». Van por `can_access?`, que es lo
# que una pantalla de permisos va a leer. Hoy son 25 llaves.
#
# **De acción** — «adentro de esta pantalla, ¿podés hacer esto?»: editar un
# cliente, cambiarle el estado a un paquete, borrarlo, crear una tarea. Son más
# finas que una sección y por ahora se quedan en código, pero **siempre contra
# una constante con nombre** (`EDICION_ROLES`, `ESTADO_CHANGE_ROLES`…), nunca
# contra una lista suelta. Ese es el segundo escalón de `RP-58`, y necesita otra
# forma de tabla: rol × acción, no rol × sección.
class PermisosEnUnaSolaFuenteTest < ActiveSupport::TestCase
  CONTROLLERS = Rails.root.join("app/controllers")

  # Una **lista suelta**: nombres de rol escritos ahí mismo.
  #
  # `Current.user&.admin?` a secas **no** cuenta, y es a propósito: el
  # cortocircuito de admin es de diseño —`can_access?` y `require_role` lo hacen
  # los dos— y precede a un chequeo contra constante en la línea siguiente. No
  # es una lista de roles, es la excepción del sistema.
  LISTA_SUELTA = /\brequire_role\(\s*:|\brequire_admin\b/
  CON_CONSTANTE = /[A-Z][A-Z0-9_]*_ROLES\b/

  # Las llaves que el `case` de `PermisosDelSistema.politica` realmente decide.
  # Se leen del archivo y no del objeto porque un `case` no se puede introspectar
  # — y leerlo es lo que hace que el lint note cuando alguien agrega un `when`.
  def llaves_del_case
    fuente = File.read(Rails.root.join("app/models/permisos_del_sistema.rb"))
    cuerpo = fuente[fuente.index("def politica")..fuente.index("\n  def editable?")]

    llaves, en_when = Set.new, false
    cuerpo.each_line do |linea|
      limpia = linea.split("#").first.to_s
      # Una línea que era solo comentario no corta el `when`: las llaves de
      # Configuración vienen con una explicación en el medio de la lista.
      next if limpia.strip.empty?

      en_when = true if limpia.match?(/^\s*when /)
      llaves.merge(limpia.scan(/:([a-z_]+)/).flatten) if en_when
      en_when = false unless limpia.rstrip.end_with?(",") || limpia.match?(/^\s*when /)
    end
    llaves
  end

  def lineas_de_permiso
    Dir.glob(CONTROLLERS.join("**/*.rb")).sort.flat_map do |archivo|
      next [] if archivo.end_with?("concerns/authorization.rb")

      nombre = Pathname.new(archivo).relative_path_from(Rails.root).to_s
      File.readlines(archivo).each_with_index.filter_map do |linea, i|
        next if linea.match?(/^\s*#/) || linea.match?(/def require_/)
        next unless linea.match?(LISTA_SUELTA) || linea.match?(CON_CONSTANTE)

        { archivo: nombre, linea: i + 1, texto: linea.strip }
      end
    end
  end

  test "ningún controller escribe una lista de roles suelta" do
    sueltas = lineas_de_permiso.reject { |l| l[:texto].match?(CON_CONSTANTE) }

    assert_empty sueltas.map { |l| "#{l[:archivo]}:#{l[:linea]} — #{l[:texto]}" }, <<~MSG
      Estas líneas deciden por rol sin pasar por `can_access?` ni por una
      constante con nombre. Mientras existan, una pantalla de permisos (RP-58)
      no puede ser fiel a lo que el sistema hace.

      Si es «¿entrás a esta pantalla?» → agregá una llave en
      `Authorization#can_access?` y usala.
      Si es «adentro, ¿podés hacer esto?» → sacá la lista a una constante
      `*_ROLES` del controller, como `EDIT_ROLES` o `ESTADO_CHANGE_ROLES`.
    MSG
  end

  # El contrapeso: si el regex deja de enganchar, el test de arriba pasa vacío y
  # contento sin haber mirado nada. Es exactamente cómo se murió en silencio un
  # test de `pre_alertas`.
  test "el lint de verdad encuentra las reglas de acción que quedan" do
    con_constante = lineas_de_permiso.select { |l| l[:texto].match?(CON_CONSTANTE) }

    assert_operator con_constante.size, :>=, 8,
                    "el regex dejó de enganchar: había 8 reglas de acción vivas"
    assert_includes con_constante.map { |l| l[:archivo] },
                    "app/controllers/tareas_controller.rb",
                    "las tres de tareas son el ejemplo canónico"
  end

  # `RP-58` paso 2a · **Ningún chequeo de autorización mira `user.rol`.**
  #
  # Con varios roles por persona, `user.rol` es solo el principal. Un chequeo que
  # lo mire deja afuera lo que el segundo rol concede — y lo deja afuera **en
  # silencio**, que es la forma en que este repo se lastima: unos lugares suman
  # los roles y otros no, y la diferencia solo aparece cuando alguien con dos
  # puestos se queja de una pantalla que a su compañero sí le abre.
  #
  # La forma correcta es `user.tiene_rol?(LISTA)`, que mira todos.
  #
  # Quedan afuera a propósito los que **muestran** el puesto —una etiqueta, una
  # bitácora, el área por defecto de una tarea nueva— y los que administran los
  # roles mismos. Ahí `rol` significa «el principal» y eso es lo que se quiere.
  MIRAN_EL_ROL_PRINCIPAL_A_PROPOSITO = %w[
    app/models/user.rb
    app/models/rol_de_usuario.rb
    app/models/permiso_de_rol.rb
    app/models/permisos_del_sistema.rb
    app/controllers/permisos_controller.rb
    app/helpers/tareas_helper.rb
    app/views/dashboard/sin_accesos.html.erb
    app/views/paquetes/show.html.erb
  ].freeze

  # `.rol` comparado contra algo: `.rol.in?(…)`, `LISTA.include?(user.rol)`,
  # `.rol == "cajero"`, `.rol.to_s`.
  COMPARA_EL_ROL = /
    \.rol\b\s*(?:\.in\?|==|!=|\.to_s|\]) |
    include\?\([^)]*\.rol\b |
    fetch\([^)]*\.rol\b |
    values_at\([^)]*\.rol\b
  /x

  def lineas_que_comparan_el_rol
    raiz = Rails.root
    Dir.glob(raiz.join("app/**/*.{rb,erb}")).sort.flat_map do |archivo|
      nombre = Pathname.new(archivo).relative_path_from(raiz).to_s
      next [] if nombre.in?(MIRAN_EL_ROL_PRINCIPAL_A_PROPOSITO)

      File.readlines(archivo).each_with_index.filter_map do |linea, i|
        next if linea.match?(/^\s*#/)
        next unless linea.match?(COMPARA_EL_ROL)

        "#{nombre}:#{i + 1} — #{linea.strip}"
      end
    end
  end

  test "ningún chequeo de autorización mira solo el rol principal" do
    assert_empty lineas_que_comparan_el_rol, <<~MSG
      Estas líneas deciden con `user.rol`, que es **solo el rol principal**.
      Quien tiene dos roles pierde en silencio lo que el segundo le da.

      Usá `user.tiene_rol?(LISTA)`, que mira todos sus roles. Si de verdad
      querés el principal —para mostrarlo, no para decidir— agregá el archivo a
      `MIRAN_EL_ROL_PRINCIPAL_A_PROPOSITO` y decí por qué.
    MSG
  end

  # El contrapeso, por lo mismo que el de arriba: si el regex deja de enganchar,
  # el test pasa vacío y contento sin haber mirado nada.
  test "el lint del rol principal de verdad engancha" do
    linea = 'return if EDIT_ROLES.include?(Current.user&.rol)'
    assert_match COMPARA_EL_ROL, linea, "el regex dejó de reconocer la forma que vino a prohibir"
    assert_match COMPARA_EL_ROL, 'user.rol.in?(ROLES)'
    assert_match COMPARA_EL_ROL, 'Current.user.rol == "cajero"'
    refute_match COMPARA_EL_ROL, 'user.tiene_rol?(EDIT_ROLES)', "la forma correcta no puede dar falso positivo"
  end

  # `RP-58` paso 1 · El registro y el código no se pueden separar, en **ninguna**
  # de las dos direcciones:
  #
  #   · una llave en el registro que el código no conoce → cae en el `else`,
  #     contesta siempre `false`, y la fila de la pantalla queda muerta;
  #   · una llave en el código que el registro no tiene → **desaparece de la
  #     pantalla**, y nadie se entera hasta que alguien pregunta por qué no
  #     puede prender algo que ve en el menú.
  #
  # La segunda es la peligrosa, porque no rompe nada: simplemente esa sección
  # deja de poder moverse.
  test "el registro de secciones y la política del código dicen lo mismo" do
    del_codigo = llaves_del_case
    del_registro = SeccionesDelSistema::TODAS.keys.map(&:to_s).to_set

    assert_empty del_registro - del_codigo,
                 "están en SeccionesDelSistema y el código no las conoce: caen en el `else`"
    assert_empty del_codigo - del_registro,
                 "el código las decide y no salen en la pantalla de permisos"
  end

  # Una llave inventada cae en el `else` y devuelve `false`: la pantalla quedaría
  # muerta sin que nadie se entere.
  test "toda llave usada en un controller la reconoce can_access?" do
    usadas = Dir.glob(CONTROLLERS.join("**/*.rb")).flat_map do |archivo|
      File.read(archivo).scan(/can_access\?\(:(\w+)\)/).flatten
    end.uniq.map(&:to_sym)

    assert usadas.size >= 15, "el regex tiene que encontrar las llaves en uso"

    sonda = ApplicationController.new
    Current.session = Struct.new(:user).new(User.new(rol: "admin"))
    desconocidas = usadas.reject { |llave| sonda.send(:can_access?, llave) }
    Current.session = nil

    # El admin entra a todo por el cortocircuito; si alguna diera false sería
    # que ni el cortocircuito corrió.
    assert_empty desconocidas, "estas llaves no las reconoce ni el admin: #{desconocidas.inspect}"
  end
end
