# `RP-58` · **La política del código**: qué puede cada rol si nadie tocó nada.
#
# Vivía adentro de `Authorization#can_access?`, o sea adentro de un controller.
# Sale acá por dos razones concretas:
#
#   1. La **pantalla de permisos** necesita el default de cada celda para poder
#      marcar cuáles están cambiadas y ofrecer «volver al código». Leerlo desde
#      un controller obligaba a instanciar uno y plantarle un `Current.session`
#      falso — un truco de test que no tiene por qué vivir en producción.
#   2. Es una función **pura**: rol y sección adentro, `true`/`false` afuera. No
#      toca `Current` ni la base. Eso la hace trivial de auditar, que es justo
#      lo que se le pide a un mapa de permisos.
#
# **El cortocircuito de admin no está acá, y es a propósito.** Vive en
# `Authorization#can_access?`, arriba de todo, y nunca baja a la base: si
# bajara, alguien podría dejarse afuera a sí mismo.
module PermisosDelSistema
  # Las secciones que **no se pueden mover desde la pantalla**, porque tocarlas
  # es regalarse permisos:
  #
  #   · `:permisos` — la pantalla misma. Una fila que se la conceda a un rol le
  #     deja darse todo lo demás en el siguiente clic.
  #   · `:usuarios` — quien administra usuarios puede ponerse `admin` a sí
  #     mismo, que es el mismo agujero por la puerta de al lado.
  #
  # Aflojar esto es una decisión, no un descuido: si algún día se abre, que sea
  # borrando una línea de acá y no por accidente.
  NO_EDITABLES = %i[permisos usuarios].freeze

  module_function

  # ¿Qué dice el código para este rol en esta sección? Sin mirar la base.
  def politica(rol, seccion)
    role = rol.to_s
    feature = seccion.to_sym

    case feature
    when :etiquetar, :entrega_personal
      role.in?(Manifiesto::ROLES_DE_MIAMI)
    # C21-07 · *"Los de prefactura, ellos son los que se encargan de recibir
    # carga."* Es el mismo grupo que la pre-factura, y va junto a propósito:
    # separarlos haría aparecer el link para gente que después choca.
    when :pre_facturas, :recibir_carga
      role.in?(Authorization::ROLES_DE_HONDURAS)
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
      role.in?(Authorization::ROLES_DE_SAN_PEDRO)
    # Las herramientas compartidas de los dos mostradores: buscar un cliente,
    # cotizar un flete, tocar el tracking de un paquete. No es una pantalla del
    # menú, pero sí una llave: `RP-58` necesita que **todo** chequeo de rol pase
    # por acá, o una pantalla de permisos diría que se puede algo que el
    # controller después niega.
    when :operacion
      role.in?(Authorization::ROLES_OPERATIVOS)
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
         :tasa_cambio, :ajustes_etiqueta,
         # `RP-58` paso 2b · Los títulos de los roles. Admin y nadie más, como el
         # resto de Configuración. **No** entra en `NO_EDITABLES`: renombrar un
         # puesto no concede nada —los permisos siguen atados al código del rol—,
         # así que dársela a alguien no le abre ninguna puerta.
         :roles,
         # `RP-58` · La pantalla de permisos misma. Admin y nadie más, y además
         # está en `NO_EDITABLES`: concedérsela a un rol le deja darse todo lo
         # demás en el siguiente clic.
         :permisos
      false
    when :marketing
      # PR-13.c: el supervisor de SAC ve lo mismo que su equipo. Autorizar
      # cambios de precio es aparte — va por PIN, no por esta tabla.
      role.in?(%w[sac supervisor_sac])
    else
      false
    end
  end

  def editable?(seccion)
    !NO_EDITABLES.include?(seccion.to_sym)
  end
end
