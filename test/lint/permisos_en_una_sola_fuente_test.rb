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
