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

  def can_access?(feature)
    return true if admin?

    role = Current.user&.rol
    case feature
    when :etiquetar, :entrega_personal
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
    # Las herramientas compartidas de los dos mostradores: buscar un cliente,
    # cotizar un flete, tocar el tracking de un paquete. No es una pantalla del
    # menú, pero sí una llave: `RP-58` necesita que **todo** chequeo de rol pase
    # por acá, o una pantalla de permisos diría que se puede algo que el
    # controller después niega.
    when :operacion
      role.in?(ROLES_OPERATIVOS)
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
    when :entregas
      role.in?(%w[entrega_despacho supervisor_caja])
    when :clientes, :pre_alertas, :paquetes
      true
    # PR-C7.40: la bandeja de tareas la ve quien las ejecuta, que es la misma
    # lista que ya usaba `TareasController`. Derivarla y no reescribirla: dos
    # copias de una lista de roles se desincronizan sin que nadie lo vea.
    when :tareas
      role.in?(TareasController::EJECUCION_ROLES)
    # C21-08 · El portal de catálogos del manifiesto vive en **Configuración**
    # desde que Jorge lo pidió el 2026-08-30, y ese bloque es admin-only.
    #
    # Suena a que contradice el pedido original —*"andate al área donde dice
    # empresa, agregame esta empresa que voy a usar"*, o sea poder delegarlo—,
    # pero el organigrama que dictó Yusef lo reconcilia: a quien delega es a
    # **Manal y Vanesa**, que *"tienen todos los poderes en el sistema"* y en
    # el sistema **son admin**. Michelle, que era el nombre en esa cita, está
    # dos niveles abajo y ya se dijo que no carga catálogos.
    # Configuración: admin y nadie más. Van **una llave por pantalla** y no una
    # sola para todas, porque así es como se ven en el menú y así es como Yusef
    # va a querer prenderlas y apagarlas: *"quitale a este título de caja que no
    # puedan hacer esto"*. Todas contestan `false` y el admin entra por el
    # cortocircuito de arriba.
    when :usuarios, :configuraciones, :reportes, :empleados, :catalogos_manifiesto,
         :empresa_settings, :sucursales, :tarifas_recolecta, :servicios_extra,
         :servicios, :proveedores, :motivos_retencion, :motivos_envio_politica,
         :plantillas_notas_cliente, :plantillas_descripcion, :categoria_precios,
         :tasa_cambio, :ajustes_etiqueta
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
