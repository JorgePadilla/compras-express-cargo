module Authorization
  extend ActiveSupport::Concern

  # C21-07 · *"Los de prefactura, ellos son los que se encargan de recibir
  # carga."* Se nombra una vez y se deriva: dos copias de una lista de roles se
  # desincronizan sin que nadie lo vea.
  ROLES_DE_HONDURAS = %w[supervisor_prefactura supervisor_caja cajero].freeze

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

  def can_access?(feature)
    return true if admin?

    role = Current.user&.rol
    case feature
    when :etiquetar, :entrega_personal
      role.in?(Manifiesto::ROLES_DE_MIAMI)
    # C21-08 · El portal de catálogos es **de Miami y nada más**. Tiene llave
    # propia y no la de `:manifiestos` porque las dos se separaron: San Pedro
    # entra al manifiesto a poner la guía y la fecha, pero no carga catálogos
    # (Jorge, 2026-08-30, sobre Michelle). Compartir la llave le habría
    # mostrado el link para después rebotarla en el controller.
    when :catalogos_manifiesto
      role.in?(Manifiesto::ROLES_DE_MIAMI)
    # C21-07 · *"Los de prefactura, ellos son los que se encargan de recibir
    # carga."* Es el mismo grupo que la pre-factura, y va junto a propósito:
    # separarlos haría aparecer el link para gente que después choca.
    when :pre_facturas, :recibir_carga
      role.in?(ROLES_DE_HONDURAS)
    # C21-02 · El manifiesto lo arma Miami, pero **no lo termina Miami**: la
    # guía del proveedor y la fecha de recibido en Honduras las llena *"la
    # encargada de operaciones en San Pedro Sula"* — Michelle, que es
    # supervisora de allá (Jorge, 2026-08-30).
    #
    # `Manifiesto::CAMPOS_DE_SAN_PEDRO` existía desde PR-M6 para eso y **su
    # gente no podía abrir la pantalla**: la sección era de Miami y nada más.
    # Que entren no les da poder de más — `Manifiesto#editable_por?` los deja
    # con esos dos campos y ni uno más, abierto o cerrado el manifiesto.
    #
    # Van los **jefes** de Honduras, no todo el grupo que recibe carga: el
    # cajero que escanea las cajas no tiene por qué entrar a la pantalla del
    # manifiesto — hay un test viejo que lo afirma y sigue teniendo razón.
    when :manifiestos
      role.in?(Manifiesto::ROLES_DE_MIAMI)
    # C21-02 · La pantalla de San Pedro. `PR-M10` había metido a los jefes de
    # Honduras dentro de `:manifiestos` para que pudieran llenar la guía y la
    # fecha; con pantalla propia, `:manifiestos` vuelve a ser de Miami y cada
    # lado entra a lo suyo por su puerta.
    when :guias_aduana
      role.in?(ROLES_DE_SAN_PEDRO)
    when :caja, :ventas, :recibos
      role.in?(%w[supervisor_caja cajero])
    when :notas_debito
      role.in?(%w[supervisor_caja supervisor_prefactura cajero])
    when :notas_credito
      role.in?(%w[supervisor_caja])
    when :cotizaciones
      role.in?(%w[supervisor_caja supervisor_prefactura cajero])
    when :financiamientos
      role.in?(%w[supervisor_caja cajero])
    when :empresa_settings
      false
    when :entregas
      role.in?(%w[entrega_despacho supervisor_caja])
    when :clientes, :pre_alertas, :paquetes
      true
    # PR-C7.40: la bandeja de tareas la ve quien las ejecuta, que es la misma
    # lista que ya usaba `TareasController`. Derivarla y no reescribirla: dos
    # copias de una lista de roles se desincronizan sin que nadie lo vea.
    when :tareas
      role.in?(TareasController::EJECUCION_ROLES)
    when :usuarios, :configuraciones, :reportes, :empleados
      false
    when :marketing
      # PR-13.c: el supervisor de SAC ve lo mismo que su equipo. Autorizar
      # cambios de precio es aparte — va por PIN, no por esta tabla.
      role.in?(%w[sac supervisor_sac])
    else
      false
    end
  end
end
