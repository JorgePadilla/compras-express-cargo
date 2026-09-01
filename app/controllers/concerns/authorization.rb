module Authorization
  extend ActiveSupport::Concern

  # C21-07 · *"Los de prefactura, ellos son los que se encargan de recibir
  # carga."* Se nombra una vez y se deriva: dos copias de una lista de roles se
  # desincronizan sin que nadie lo vea.
  ROLES_DE_HONDURAS = %w[supervisor_prefactura supervisor_caja cajero].freeze

  # Todo el que **toca carga**: los dos mostradores. Aparecía escrita a mano,
  # con sus cinco roles, en tres controllers distintos —el autocomplete de
  # clientes, el cotizador de flete y las acciones sobre el tracking de un
  # paquete—. Son las herramientas compartidas de los dos mostradores, no una
  # sección de nadie.
  ROLES_OPERATIVOS = (Manifiesto::ROLES_DE_MIAMI + ROLES_DE_HONDURAS).freeze

  # C21-02 · Los que le ponen al manifiesto lo que Miami no puede: la guía del
  # proveedor y la fecha de recibido en Honduras.
  #
  # Se **deriva de `User::ROLES_AUTORIZANTES`**, que es la lista de jefes de
  # Honduras que el repo ya tenía con nombre propio — la misma que decide quién
  # lleva PIN. Escribirla otra vez a mano es cómo se desincronizan.
  #
  # Y cubre a quien tiene que cubrir: Yusef, 2026-08-30, sobre Michelle —
  # *"Sub-Jefa de área de Caja y SAC"*— y Bessy —*"Supervisora de Caja y
  # SAC"*—. Con la lista escrita a mano como «los supervisores que reciben
  # carga», Michelle quedaba afuera si su usuario dice `supervisor_sac`.
  ROLES_DE_SAN_PEDRO = (User::ROLES_AUTORIZANTES - %w[admin]).freeze

  included do
    helper_method :admin?, :can_access?
  end

  private

  def require_admin
    require_role # no roles passed → only admin? guard passes
  end

  # `RP-58` paso 2a: pregunta por **todos** los roles de la persona, no solo el
  # principal. Con `rol` a secas, quien es Caja y SAC entraba únicamente a lo de
  # Caja, y lo que el segundo rol le daba se le negaba sin decírselo.
  def require_role(*roles)
    return if Current.user&.admin?

    unless Current.user&.tiene_rol?(roles)
      redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion."
    end
  end

  def require_location(*locations)
    return if Current.user&.admin?

    unless locations.map(&:to_s).include?(Current.user&.ubicacion)
      redirect_to root_path, alert: "Esta seccion no esta disponible en tu ubicacion."
    end
  end

  def admin?
    Current.user&.admin?
  end

  # `RP-58` · Tres capas, en este orden y por esta razón:
  #
  #   1. **Admin pasa siempre.** Es un cortocircuito, no una fila: nunca baja a
  #      la base, así que nadie puede dejarse afuera a sí mismo — ni por error
  #      ni a propósito.
  #   2. **La excepción**, si alguien la puso desde la pantalla de permisos.
  #   3. **El código** (`PermisosDelSistema.politica`), que es el default.
  #
  # Guardar solo las excepciones y no la matriz entera tiene una consecuencia
  # que vale nombrar: una celda que nadie tocó **sigue al código para siempre**.
  # Si mañana se cambia la política de una sección, las celdas sin fila se
  # mueven solas; las tocadas a mano no, y la pantalla las marca.
  # `RP-58` paso 2a · Con varios roles **se resuelve rol por rol y se suma**, y
  # el orden importa más de lo que parece.
  #
  # La forma equivocada —y la que sale sola— es juntar primero las excepciones
  # de todos los roles en un mapa y resolver una vez. Ahí una excepción que le
  # niega la sección al rol A **le pisa al rol B el permiso que el código le
  # daba**, y la persona pierde un acceso que nadie le quitó: el que movió esa
  # celda estaba pensando en el rol A.
  #
  # Resolviendo por separado, cada rol contesta con sus propias reglas —su
  # excepción si la hay, si no el código— y basta que **uno** diga que sí. Los
  # roles suman; para quitar algo hay que quitárselo a todos sus roles, o
  # quitarle un rol.
  def can_access?(feature)
    return true if admin?

    roles = Current.user&.roles.to_a
    return false if roles.empty?

    roles.any? { |rol| rol_puede?(rol, feature) }
  end

  def rol_puede?(rol, feature)
    excepcion = permisos_del_rol.dig(rol, feature.to_s)
    return excepcion unless excepcion.nil?

    PermisosDelSistema.politica(rol, feature)
  end

  # Las excepciones del rol actual, **una sola consulta por request**.
  # `can_access?` se llama ~100 veces por página entre controllers y vistas;
  # una consulta por llamada sería absurdo. `Current` se limpia solo entre
  # requests, así que no hay estado que se filtre de uno a otro.
  def permisos_del_rol
    Current.permisos ||= PermisoDeRol.mapa_para(Current.user&.roles)
  end
end
