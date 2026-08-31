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

  def require_role(*roles)
    return if Current.user&.admin?

    unless roles.map(&:to_s).include?(Current.user&.rol)
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
  def can_access?(feature)
    return true if admin?

    rol = Current.user&.rol
    return false if rol.blank?

    excepcion = permisos_del_rol[feature.to_s]
    return excepcion unless excepcion.nil?

    PermisosDelSistema.politica(rol, feature)
  end

  # Las excepciones del rol actual, **una sola consulta por request**.
  # `can_access?` se llama ~100 veces por página entre controllers y vistas;
  # una consulta por llamada sería absurdo. `Current` se limpia solo entre
  # requests, así que no hay estado que se filtre de uno a otro.
  def permisos_del_rol
    Current.permisos ||= PermisoDeRol.mapa_para(Current.user&.rol)
  end
end
