class EtiquetarController < ApplicationController
  # PR: el prepago de Miami ahora también se marca acá, no solo en
  # /entrega_personal. El sellado va por el concern para que las dos pantallas
  # no se separen — que es como llegó a faltar la forma de pago.
  include PrepagoMiami
  # Encontrar el paquete que la pre-alerta dejó esperando. Va por concern por lo
  # mismo: `create_single` lo hacía y `create_split` no, y por esa diferencia un
  # tracking pre-alertado que llegaba dividido imprimía 3 etiquetas para 2 cajas.
  include ReconciliarPreAlerta
  include NotificaRecibido
  # PR-C6.22: etiquetar es **recibir**, no empacar.
  #
  # Yusef, 2026-08-08, revisando la bitácora de un paquete recién etiquetado:
  #
  #   > "**Empacado dice, y empacado no es lo que sigue.** Queda aquí en
  #   >  recibido, porque apenas se recibió y se tiene ahí. Cuando hagamos lo
  #   >  que hablamos del empaque, ahí sí va a decir empacado, porque ya lo
  #   >  escaneamos, lo agregamos y lo metimos."
  #
  # `empacado` queda reservado para el módulo de empaque, que todavía no
  # existe — él mismo lo difirió en esa misma reunión. Mientras tanto la
  # columna `fecha_empacado` se queda vacía a propósito: es el registro de un
  # paso que nadie dio.
  #
  # Precedente en el repo: `EntregaPersonalController` ya recibe así.
  ESTADO_AL_ETIQUETAR = "recibido_miami".freeze

  # PR-C6.31: el peso y las medidas de cada caja se leen igual acá y en
  # Entrega Personal, porque las dos pantallas comparten el mismo partial.
  include MedidasPorCaja

  before_action :authorize_etiquetar
  before_action :load_tipo_envio_sesion
  before_action :require_tipo_envio_sesion, only: :create

  def index
    # PR-C6.10: `?paquete_id=` recarga el formulario con lo que el paquete ya
    # tiene, para actualizarlo acá mismo. Yusef: "me mandaste a editar y yo no
    # quiero editar mi paquete... que te cargue aquí la lista".
    @paquete = paquete_a_actualizar || Paquete.new
    @modo_actualizacion = @paquete.persisted?
    # PR-C6.23: `?cambio_servicio=1` viene del botón "Cambio de servicio" del
    # modal de duplicado. Marca el check y abre el modal del destino de una
    # vez. Yusef: "si yo presiono cambio de servicio, me tire aquí de un solo
    # a esto" — antes ese botón mandaba a /paquetes, "envía donde no es".
    @abrir_cambio_servicio = @modo_actualizacion && params[:cambio_servicio].present?
    assigns_del_formulario
  end

  # El operario elige el tipo de envío que va a trabajar en este lote, y en
  # qué sucursal está recibiendo. Los dos quedan en session y aplican a cada
  # paquete que etiquete hasta finalizar.
  #
  # PR-C6.5: la sucursal de recepción es lo que le da número de recepción al
  # paquete. Antes `/etiquetar` no asignaba ninguna sucursal —ni una sola
  # mención en el controller ni en la vista— así que **ningún paquete
  # etiquetado tenía número**, y su etiqueta terminaba imprimiendo el tracking
  # en el código de barras. Yusef: "el código de barra que está aquí es el
  # warehouse, no es el tracking".
  #
  # Va en la sesión y no en el formulario porque no cambia paquete a paquete:
  # el que recibe está parado en un lugar. Yusef lo describió así — "está
  # alguien en Miami recibiendo, o en Panamá, o en China".
  def iniciar_sesion
    tipo = TipoEnvio.activos.find_by(id: params[:tipo_envio_id])
    return redirect_to(etiquetar_path, alert: "Seleccioná un tipo de envío válido.") if tipo.nil?

    # Solo una de las ofrecidas: un id de otra sucursal —inactiva, o una que no
    # recibe— cae al default en vez de aceptarse.
    sucursal = sucursales_recepcion_posibles.find { |s| s.id == params[:sucursal_recepcion_id].to_i } ||
               sucursal_recepcion_por_defecto
    if sucursal.nil?
      return redirect_to etiquetar_path,
                         alert: "Seleccioná en qué sucursal estás recibiendo."
    end

    session[:etiquetar_tipo_envio_id] = tipo.id
    session[:etiquetar_sucursal_recepcion_id] = sucursal.id
    # Sin flash: el banner de sesión activa ya comunica el tipo elegido.
    redirect_to etiquetar_path
  end

  # Cierra el lote actual; la próxima visita vuelve a preguntar el tipo.
  def finalizar_sesion
    session.delete(:etiquetar_tipo_envio_id)
    session.delete(:etiquetar_sucursal_recepcion_id)
    redirect_to etiquetar_path, notice: "Sesión de etiquetado finalizada."
  end

  # Actualiza un paquete SIN salir de /etiquetar.
  #
  # La línea divisoria la definió Yusef y se respeta en el servidor:
  #
  #   > "Si ellos entran a actualizar acá es porque van a actualizar **datos
  #   >  del paquete**, de lo que ellos ingresan." · "Si van a actualizar un
  #   >  **estado** actual del paquete, eso sí lo van a tener que hacer en
  #   >  todos los paquetes."
  #
  # Por eso `paquete_params` no permite `estado` — y hay un test que lo fija.
  #
  # El tipo de envío **no** se pisa con el de la sesión al actualizar. Si el
  # paquete es CEM y el operario está en sesión CER, corregirle el peso no
  # puede convertirlo en CER. La sesión manda al crear; acá solo si pidió
  # cambio de servicio explícito.
  def update
    @paquete = Paquete.find(params[:id])
    @modo_actualizacion = true

    unless aplicar_cambio_servicio(@paquete)
      return render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
    end

    # Avisa, no bloquea. Yusef, 2026-08-19: *"es exprés y me está dejando
    # actualizar en CER"*. `conflicto_con_la_sesion` se llamaba en las dos rutas
    # de alta y no acá.
    #
    # No se rechaza a propósito: corregirle el peso a un CEM desde una sesión CER
    # no puede convertirlo en CER, y por eso al actualizar el tipo de envío
    # **nunca** se pisa con el de la sesión. Lo que faltaba era decirlo. Jorge lo
    # planteó así en la llamada —*"es correcto que si el paquete tiene otro tipo
    # de envío del que estamos trabajando, sí te tiene que tirar"*— y Yusef dijo
    # que sí.
    @aviso_de_otro_tipo = aviso_de_tipo_distinto(@paquete)

    # La cantidad de cajas se delega al ajuste de split, que crea o elimina
    # las que correspondan (PR-C6.7) y bloquea si alguna ya se cobró.
    #
    # C20-04, la regla que puso Yusef: *"en impresión de etiquetas es el que te
    # marca la cantidad de cajas"* — o sea que lo que el operario conteste acá
    # manda, para arriba y para abajo.
    nueva_cantidad = cantidad_de_cajas_pedida

    # Sobre un esperado no se ajusta nada: todavía no llegó, no tiene número, y
    # sus "cajas" nuevas nacerían con el estado de esperado —invisibles para la
    # impresión, que las filtra—. Recibirlo es escanearlo, que es el camino que
    # sí sabe convertirlo (`crear_split!` con `reusar:`).
    if ajusta_cajas?(nueva_cantidad) && Paquete::NO_SON_CAJAS.include?(@paquete.estado)
      return render_create_error(
        "Este paquete todavía es un esperado de una pre-alerta: se recibe escaneándolo, no actualizándolo."
      )
    end

    begin
      # Todo o nada. El contrato viejo —"si una caja a eliminar ya se cobró,
      # no se guarda nada"— se cumplía por orden, pero al revés no: si el
      # ajuste pasaba y el `save` de después fallaba, las cajas creadas o
      # borradas ya quedaban. La transacción cubre los dos lados.
      Paquete.transaction do
        # C18-04: un paquete que llega acá sin sucursal de recepción —nació en
        # /paquetes, o es un esperado— toma la de la sesión: sin ella no hay
        # número de recepción ni Warehouse Receipt. No se pisa la que ya tenga.
        #
        # C20-04: y va ANTES del ajuste, porque el ajuste necesita el número
        # —que sale de esta sucursal— para saber quiénes son las hermanas.
        @paquete.sucursal_recepcion ||= @sucursal_recepcion_sesion

        if ajusta_cajas?(nueva_cantidad)
          restantes = Paquete.ajustar_split!(@paquete, nueva_cantidad)
          # Al reducir, la caja que se está editando puede ser una de las que
          # se van: al re-escanear se abre la más nueva, y ésa es justamente la
          # que `ajustar_split!` borra primero. Seguir con ella era un
          # `RecordNotFound` en la cara del operario, así que el formulario
          # pasa a hablar de una caja que sí quedó.
          @paquete = restantes.find { |c| c.id == @paquete.id } || restantes.first
          @reanclado = @paquete.id != params[:id].to_i
          # `ajustar_split!` relee las cajas de la base, así que el objeto que
          # queda no trae el cambio de servicio que se aplicó en memoria más
          # arriba. Se vuelve a aplicar sobre el que de verdad se va a guardar.
          aplicar_cambio_servicio(@paquete)
        end

        # Lo que el formulario traía de peso y medidas era de la caja que se
        # fue; no se le pega a la que sobrevivió.
        cambios = paquete_params.except(:cantidad_paquetes)
        cambios = cambios.except(*MedidasPorCaja::CAMPOS_POR_CAJA) if @reanclado
        @paquete.assign_attributes(cambios)

        if (prov_str = proveedor_string_param) != :missing
          @paquete[:proveedor] = prov_str
        end
        aplicar_prepago_miami(@paquete)
        @paquete.save!
        propagar_envio_a_hermanas(@paquete)
      end
    rescue Paquete::CajaNoEliminable => e
      return render_create_error(e.message)
    rescue ActiveRecord::RecordInvalid
      return render_create_error("No se pudo actualizar el paquete.")
    end

    # Lo de acá abajo va fuera de la transacción a propósito: son avisos y
    # pantalla, no datos. Un correo no se manda dos veces si algo se reintenta.
    #
    # C18-06: marcar «enviado según política» al re-escanear es la misma
    # transición que en /paquetes: el cliente se entera igual (gemela).
    if @paquete.saved_change_to_enviado_por_politica? && @paquete.enviado_por_politica?
      notificar_recibido(@paquete, pre_alerta_vinculada: false)
    end
    @paquetes_hoy = paquetes_hoy_count
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.prepend("flash-messages", partial: "shared/flash",
                               locals: { notice: aviso_de_actualizacion }),
          # `data-volver`: al terminar de actualizar, la pantalla tiene que
          # volver a modo alta.
          #
          # Jorge, 2026-08-19: *"«Actualizando 9234690331…» siempre se queda en
          # la vista, no desaparece al guardar"*. El banner era el síntoma
          # visible; lo de abajo es peor. El `form` se renderiza en el servidor
          # con `PATCH /etiquetar/:id`, y `clearForm` limpia los **campos**
          # pero no la acción del formulario — así que el paquete siguiente
          # que se escaneara se iba a guardar **encima del anterior**.
          #
          # C20-04: el id es el del paquete que quedó, que puede no ser el que
          # entró — al reducir, la caja que se editaba puede ser la que se fue.
          # De ahí sale la impresión de TODAS las etiquetas del envío, que es
          # lo que Yusef pidió: *"tenés que imprimirlas todas, porque si no en
          # San Pedro… este dice cuatro y usted dice tres"*.
          turbo_stream.append("etiquetar-events",
                              "<div data-etiquetar-target='event' data-action='paquete-saved' " \
                              "data-guia='#{@paquete.guia}' data-print='#{params[:print]}' " \
                              "data-volver='true' " \
                              "data-paquete-id='#{@paquete.id}'></div>")
        ]
      end
      format.html { redirect_to etiquetar_path, notice: aviso_de_actualizacion }
    end
  end

  # PR-C7.17: la cantidad de cajas **sale de contar las filas**, no de un campo.
  #
  # Antes salía de `paquete_params[:cantidad_paquetes]`, y cuando `PR-C7.04`
  # forkeó el bloque de peso y medidas en dos, esta pantalla se quedó sin ese
  # campo — así que la cantidad era siempre 0 y **nunca se creaba un split**.
  # Jorge: *"en etiquetar no me deja agregar más cajas como en entrega
  # personal"*.
  #
  # Derivarla de las filas es además lo que `PR-C6.31` dejó escrito: si hay dos
  # fuentes para el mismo número, alguna va a mentir. Ahora hay una, y es la
  # misma que usa `/entrega_personal`.
  def create
    cajas = medidas_por_caja

    case cajas.size
    when 0 then crear_sin_medir                      # nunca agregó: pregunta cuántas
    when 1 then create_single(cajas.values.first)    # una caja: sus datos mandan
    else        create_split(cajas.size)
    end
  end

# PR-C6.28: el supervisor de Miami le quita a un paquete el cobro por cambio
# de servicio, con su PIN. Yusef: "que le digan al supervisor de ellos allá
# en Miami... y que él lo pueda eliminar el cobro con el usuario de él".
#
# Va acá y no en /paquetes porque es donde el digitador se da cuenta del
# error: "es que ellos no manejan la página de paquetes".
def quitar_cambio_servicio
  paquete = Paquete.find(params[:id])

  QuitarCambioServicio.new(
    paquete: paquete,
    supervisor: User.find_by(id: params[:supervisor_id]),
    pin: params[:pin],
    motivo: params[:motivo]
  ).call

  redirect_to etiquetar_path(paquete_id: paquete.id),
              notice: "Se quitó el cobro por cambio de servicio de #{paquete.tracking}."
rescue QuitarCambioServicio::NoPermitido, QuitarCambioServicio::PinInvalido,
       QuitarCambioServicio::YaFacturado => e
  redirect_to etiquetar_path(paquete_id: params[:id]), alert: e.message
end

  private

  # `medidas` son las de la única caja agregada, cuando el operario usó Agregar
  # para una sola. Sin eso, ese peso y esas medidas se perdían.
  # Sin ninguna caja medida, la cantidad la dice el modal de «¿cuántas
  # etiquetas?».
  #
  # Yusef, 2026-08-18: *"en etiquetar casi nunca medimos y pesamos"*, y por eso
  # *"cuando la cantidad de cajas guardadas sea cero, que pregunte cuántas son"*.
  # Tres etiquetas son **tres cajas**, no tres copias del mismo papel: el flete
  # se cobra por caja, el Warehouse Receipt cuenta piezas y cada etiqueta lleva
  # su `1/3`. Un envío de tres cajas grabado como un bulto se cobra mal.
  def crear_sin_medir
    cantidad = etiquetas_pedidas
    if cantidad.nil?
      # `render_create_error` re-renderiza el formulario, y el formulario
      # necesita un objeto: sin esto el 422 revienta con un 500.
      @paquete = Paquete.new(paquete_params)
      return render_create_error("La cantidad de etiquetas va de 1 a #{MAX_ETIQUETAS}.")
    end

    cantidad > 1 ? create_split(cantidad) : create_single
  end

  # Cuántas etiquetas pidió el modal. `nil` significa que mandó un número que no
  # se puede grabar.
  #
  # La pistola dispara Enter y el campo es numérico: un dedo de más grabaría
  # cientos de paquetes y mandaría cientos de etiquetas a la impresora. El tope
  # está en el navegador (`max="99"`) y otra vez acá, porque el navegador se
  # puede saltar.
  #
  # Va como parámetro suelto y **no** dentro de `paquete[...]`: el bug de
  # `PR-C6.31` fue tener dos campos declarando la misma cantidad, ganaba el
  # último y el split se caía en silencio.
  MAX_ETIQUETAS = 99
  def etiquetas_pedidas
    crudo = params[:etiquetas]
    return 1 if crudo.blank?

    n = Integer(crudo, exception: false)
    return nil if n.nil? || n < 1 || n > MAX_ETIQUETAS

    n
  end

  def create_single(medidas = {})
    # Reconciliación: si ya existe un paquete "esperado" creado desde una
    # pre-alerta con este tracking, lo transicionamos en lugar de crear uno
    # nuevo. La regla vive en `ReconciliarPreAlerta` porque `create_split` la
    # necesita igual — escrita acá otra vez, las dos rutas se separan.
    escaneado = paquete_params[:tracking].to_s.strip
    esperado = paquete_esperado(escaneado)
    tracking, secundario = trackings_reconciliados(esperado, escaneado)

    if esperado
      @paquete = esperado
      @paquete.assign_attributes(paquete_params.merge(medidas))
      @paquete.tracking = tracking
      @paquete.tracking_secundario = secundario if secundario && @paquete.tracking_secundario.blank?
    else
      @paquete = Paquete.new(paquete_params.merge(medidas))
    end
    @paquete.estado = ESTADO_AL_ETIQUETAR
    @paquete.user = Current.user
    # El tipo de envío lo manda la sesión de etiquetado, no el form.
    @paquete.tipo_envio_id = @tipo_envio_sesion.id
    # PR-C6.5: y la sucursal donde se está recibiendo, que es de donde sale el
    # número de recepción. Sin esto el paquete nace sin número y su etiqueta
    # imprime el tracking en el código de barras.
    @paquete.sucursal_recepcion = @sucursal_recepcion_sesion
    # PR-C6.37: la sucursal de RETIRO sale del cliente. El campo del paquete ya
    # existia ("ese mismo, no es que vas a crear algo mas") pero nadie lo
    # llenaba, asi que la etiqueta caia al `ciudad` del cliente.
    @paquete.sucursal ||= @paquete.cliente&.sucursal_retiro
    # PR-C6.8: si marcó cambio de servicio, el destino pisa al de la sesión.
    # Antes el flag quedaba marcado y el tipo se quedaba en el de la sesión —
    # "cambio de servicio → CER a CKM no funciona".
    unless aplicar_cambio_servicio(@paquete)
      render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
      return
    end
    if (conflicto = conflicto_con_la_sesion(@paquete))
      render_create_error(conflicto)
      return
    end
    if (prov_str = proveedor_string_param) != :missing
      @paquete[:proveedor] = prov_str
    end
    aplicar_prepago_miami(@paquete)

    if @paquete.save
      vinculadas = link_pre_alertas(@paquete)
      # C17-02: la tarea que se dejó desde la franja mientras se recibía esta
      # caja pasa a colgar de ella.
      Tarea.atar_al_paquete!(@paquete)
      absorber_esperado_del_secundario(@paquete)
      notificar_recibido(@paquete, pre_alerta_vinculada: vinculadas > 0)
      @paquetes_hoy = paquetes_hoy_count

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("paquetes-counter", @paquetes_hoy.to_s),
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: "Paquete #{@paquete.tracking} guardado exitosamente." }),
            turbo_stream.append("etiquetar-events", "<div data-etiquetar-target='event' data-action='paquete-saved' data-guia='#{@paquete.guia}' data-print='#{params[:print]}' data-paquete-id='#{@paquete.id}'></div>")
          ]
        end
        format.html do
          redirect_to etiquetar_path, notice: "Paquete #{@paquete.tracking} guardado exitosamente."
        end
      end
    else
      render_create_error
    end
  end

  # Crea N paquetes "hijos" para un tracking dividido en varias cajas físicas.
  # El digitador llenó los datos una sola vez; el sistema replica y asigna
  # numero_caja 1..N. Imprime N etiquetas si se pidió print.
  def create_split(total_cajas)
    attrs = paquete_params.except(:cantidad_paquetes, :numero_caja).merge(
      estado: ESTADO_AL_ETIQUETAR,
      user: Current.user,
      tipo_envio_id: @tipo_envio_sesion.id,
      # Las N cajas comparten el número madre, y ese número sale de acá.
      sucursal_recepcion: @sucursal_recepcion_sesion,
      # PR-C6.37: y la sucursal de RETIRO, que sale del cliente. Va acá y no
      # solo en `create_single` porque las cajas de un split se guardan por
      # otro camino — y sin esto heredaban todo menos esto.
      sucursal_id: paquete_params[:sucursal_id].presence ||
                   Cliente.find_by(id: paquete_params[:cliente_id])&.sucursal_retiro_id
    )
    # Mismo guard que el single: no se graban cajas bajo el tipo equivocado.
    if (conflicto = conflicto_con_la_sesion(Paquete.new(paquete_params)))
      @paquete = Paquete.new(paquete_params)
      return render_create_error(conflicto)
    end

    # El cambio de servicio aplica a las N cajas por igual: es el mismo
    # tracking, no se parte en dos servicios distintos.
    if ActiveModel::Type::Boolean.new.cast(paquete_params[:solicito_cambio_servicio])
      destino = TipoEnvio.activos.find_by(id: params.dig(:paquete, :tipo_envio_destino_id))
      unless destino
        @paquete = Paquete.new(paquete_params)
        return render_create_error("Marcaste cambio de servicio: elegí a qué tipo de envío cambia.")
      end
      attrs = attrs.merge(
        tipo_envio_id: destino.id,
        tipo_envio_anterior_id: @tipo_envio_sesion.id
      )
    end

    # Lo mismo que hace `create_single`: si la pre-alerta dejó un paquete
    # esperando con este tracking, ese se vuelve la Caja 1 en vez de quedarse
    # huérfano al lado. El tracking del cliente manda sobre las N cajas —
    # comparten uno solo— y lo que escupió la pistola viaja como secundario en
    # `attrs`, así que cualquiera de ellas se encuentra volviendo a escanear.
    escaneado = paquete_params[:tracking].to_s.strip
    esperado = paquete_esperado(escaneado)
    tracking, secundario = trackings_reconciliados(esperado, escaneado)
    attrs = attrs.merge(tracking: tracking)
    attrs = attrs.merge(tracking_secundario: secundario) if secundario && attrs[:tracking_secundario].blank?

    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas,
                                    por_caja: medidas_por_caja, reusar: esperado)
    if (prov_str = proveedor_string_param) != :missing && prov_str.present?
      paquetes.each { |p| p.update_column(:proveedor, prov_str) }
    end
    # El pago es uno solo para el envío, así que marca las N cajas: el cliente
    # pagó el tracking, no la caja 2 de 3.
    paquetes.each { |p| aplicar_prepago_miami(p); p.save! }
    @paquete = paquetes.first
    vinculadas = paquetes.sum { |p| link_pre_alertas(p) }
    # El esperado del secundario se absorbe **una vez**, en la Caja 1: es un
    # solo bulto anunciado dos veces, no uno por caja.
    absorber_esperado_del_secundario(paquetes.first)
    # C17-02: una vez, a la Caja 1 — el bloqueo por tareas es por caja.
    Tarea.atar_al_paquete!(paquetes.first)
    # Un correo por envío, no uno por caja.
    notificar_recibido(paquetes.first, pre_alerta_vinculada: vinculadas > 0)
    @paquetes_hoy = paquetes_hoy_count

    respond_to do |format|
      format.turbo_stream do
        # C20-06: un evento por caja, pero **una sola impresión**.
        #
        # Cada evento con `data-print` abre su propia pestaña, y cada pestaña
        # imprime TODAS las hermanas (`?hermanas=1`) — o sea N pestañas × N
        # etiquetas: dos cajas son cuatro etiquetas, tres son nueve. Hoy no se
        # nota porque Chrome deja pasar un solo popup por gesto del usuario
        # (el mismo límite de `PR-C7.28`), así que el día que alguien le dé
        # permiso al sitio en la estación de Miami empieza a salir papel de
        # más.
        #
        # Los N eventos se quedan: cada uno dispara su sonido y su limpieza de
        # formulario. Lo que se marca una sola vez es la impresión.
        events = paquetes.each_with_index.map do |p, i|
          imprime = i.zero? ? params[:print] : nil
          "<div data-etiquetar-target='event' data-action='paquete-saved' " \
            "data-guia='#{p.guia}' data-print='#{imprime}' data-paquete-id='#{p.id}'></div>"
        end.join

        render turbo_stream: [
          turbo_stream.update("paquetes-counter", @paquetes_hoy.to_s),
          turbo_stream.prepend("flash-messages", partial: "shared/flash",
                               locals: { notice: "Tracking dividido en #{total_cajas} cajas: #{paquetes.map(&:guia).join(', ')}." }),
          turbo_stream.append("etiquetar-events", events)
        ]
      end
      format.html do
        redirect_to etiquetar_path, notice: "Tracking dividido en #{total_cajas} cajas."
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @paquete = e.record
    render_create_error
  end

  # Todo lo que la pantalla necesita para dibujarse, venga de un GET limpio o
  # de un 422.
  #
  # C20-01: vivía copiado en `index` y en `render_create_error`, y las copias
  # se desincronizaron: `@supervisores_cobro` (PR-C6.28) se agregó solo en
  # `index`. La vista lo usa en el banner del cobro por cambio de servicio, que
  # sale cuando `@modo_actualizacion && solicito_cambio_servicio?` — o sea que
  # **cualquier** error al actualizar un paquete con cambio de servicio moría
  # con `undefined method 'any?' for nil` y le tapaba al operario el mensaje
  # que explicaba qué había que corregir. Yusef lo vio como "ahí tira el rojo".
  #
  # Un solo lugar: la próxima ivar que se agregue no puede volver a faltarle a
  # la mitad de los caminos.
  def assigns_del_formulario
    @paquetes_hoy = paquetes_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    # Las que pueden emitir número de recepción. Si hay una sola, la vista no
    # pregunta nada y la manda en un hidden.
    @sucursales_recepcion = sucursales_recepcion_posibles
    @sucursal_recepcion_sugerida = @sucursal_recepcion_sesion || sucursal_recepcion_por_defecto
    @carriers = Carrier.where(activo: true).order(:nombre)
    # PR-C6.28: quienes pueden quitar el cobro por cambio de servicio.
    @supervisores_cobro = User.activos.where(rol: QuitarCambioServicio::ROLES)
                              .where.not(pin_digest: nil).order(:nombre)
    @motivos_retencion = MotivoRetencion.activos.ordered
    @motivos_envio_politica = MotivoEnvioPolitica.activos.ordered
  end

  def render_create_error(mensaje = "No se pudo guardar el paquete.")
    assigns_del_formulario
    # PR-C6.23: si el rechazo fue justamente por no haber elegido el destino
    # del cambio de servicio, el modal vuelve abierto. Antes el 422
    # re-renderizaba con el check marcado y el modal cerrado, así que el
    # mensaje pedía elegir algo que no estaba a la vista.
    @abrir_cambio_servicio = ActiveModel::Type::Boolean.new.cast(
      paquete_params[:solicito_cambio_servicio]
    ) && params.dig(:paquete, :tipo_envio_destino_id).blank?
    # Las cajas que venían en el request vuelven a la pantalla. `render :index`
    # rehace la página entera y las filas las pinta el JS, así que sin esto
    # CUALQUIER error de validación —falta el cliente, tracking repetido— le
    # borraba al operario todas las cajas que ya había pesado y medido.
    @cajas_cargadas = medidas_por_caja
    flash.now[:alert] = mensaje
    render :index, status: :unprocessable_entity
  end

  # Aplica el destino del cambio de servicio, si lo pidieron.
  #
  # El tipo de envío normalmente lo manda la sesión de etiquetado. El cambio
  # de servicio es la **excepción explícita**: el paquete sale de la sesión en
  # la que se está trabajando, y por eso se registra de dónde venía.
  #
  # Devuelve false si marcó el flag y no eligió destino, para que el caller
  # corte antes de guardar. **No** se usa `errors.add` acá: el `valid?` que
  # corre adentro de `save` limpia los errores, así que el paquete se
  # guardaría igual — a medias, con el flag prendido sobre el tipo viejo, que
  # es justo lo que pasaba antes.
  def aplicar_cambio_servicio(paquete)
    return true unless ActiveModel::Type::Boolean.new.cast(paquete_params[:solicito_cambio_servicio])

    destino = TipoEnvio.activos.find_by(id: params.dig(:paquete, :tipo_envio_destino_id))
    return false if destino.nil?

    paquete.aplicar_cambio_servicio(destino)
    true
  end

  # El cambio de servicio es del **envío**, no de una caja.
  #
  # Yusef, 2026-08-19, después de cambiar un envío de CER a EXPRESS: *"el tercero
  # lo reconoce como exprés y los otros dos como CER… debería de cambiar
  # todas"*. Un envío repartido en dos servicios no existe: se cobra con dos
  # tarifas distintas y viaja en dos manifiestos.
  #
  # Al dar de alta ya salía bien —`create_split` mete el destino en los `attrs`
  # de las N cajas—; el que quedaba corto era el update, que solo tocaba la caja
  # abierta en pantalla.
  #
  # `cajas_del_mismo_split` y no las hermanas por tracking: la clave del split es
  # el número madre, y dos splits distintos pueden compartir tracking porque el
  # courier recicla números.
  # Lo que se corrige al actualizar una caja es del ENVÍO, no de esa caja.
  #
  # C20-05. Probado en vivo sobre un envío de dos cajas a nombre de Diego:
  # *"después vine yo y lo actualicé y lo cambié al nombre de Sofía"* → *"aquí
  # hay una cuestión: quedó a nombre de Diego uno y el otro quedó a nombre de
  # Sofía"*. Lo mismo con la retención: *"mira que decía RET… solo uno te metió
  # RET"*. `crear_split!` sí reparte estos datos entre las N cajas al dar de
  # alta; el update nunca aprendió a hacerlo.
  #
  # Es la misma familia del *"el tercero lo reconoce como exprés y los otros dos
  # como CER… debería de cambiar todas"* de la Conversación 14, que se había
  # arreglado solo para el tipo de envío.
  #
  # **Se escribe lo que vino en el formulario, sin mirar `saved_changes`**, por
  # dos razones. Una: los motivos son `has_many through` y no aparecen ahí, así
  # que la retención nunca se habría propagado. Y dos: reescribir el valor
  # aunque "no cambió" hace que actualizar cualquier caja **converja** un envío
  # que ya estaba partido — el de Diego y Sofía se arregla tocando cualquiera
  # de las dos, sin tener que adivinar cuál quedó bien.
  ATRIBUTOS_DEL_ENVIO = %i[
    tracking tracking_secundario cliente_id tercero_id tercero_nombre
    descripcion remitente expedido_por notas_internas
    retener_miami notas_retencion enviado_por_politica notas_envio_politica
    motivo_retencion_ids motivo_envio_politica_ids
  ].freeze

  def propagar_envio_a_hermanas(paquete)
    hermanas = Paquete.cajas_del_mismo_split(paquete).where.not(id: paquete.id).to_a
    return if hermanas.empty?

    del_envio = paquete_params.to_h.symbolize_keys.slice(*ATRIBUTOS_DEL_ENVIO)
    prov_str = proveedor_string_param

    hermanas.each do |caja|
      caja.assign_attributes(del_envio)
      if caja.tipo_envio_id != paquete.tipo_envio_id
        caja.aplicar_cambio_servicio(paquete.tipo_envio)
        # …pero el CARGO es del envío, y lo lleva la caja que el operario
        # tocó. `aplicar_cambio_servicio` prende el flag de paso, y la
        # pre-factura arma un ítem **por paquete marcado** — con las tres
        # marcadas, un cambio de CER a CEM se cobraba L.300 en vez de L.100.
        # Solo se apaga acá, donde lo prendimos nosotros: un flag que la caja
        # ya traía de antes no se toca.
        caja.solicito_cambio_servicio = false
      end
      caja[:proveedor] = prov_str if prov_str != :missing
      aplicar_prepago_miami(caja)
      caja.save!
    end
  end

  # ¿Este paquete pertenece a otro tipo de envío que el de la sesión?
  #
  # Devuelve el mensaje de error, o nil si está todo bien.
  #
  # **Esto es la mitad que cobra bien.** El modal del front es la mitad
  # visible; sin el rechazo del servidor un paquete con pre-alerta CKM
  # escaneado en sesión CER **se guardaba como CER en silencio**, porque
  # `create_single` hace `tipo_envio_id = @tipo_envio_sesion.id` sin preguntar.
  #
  # Yusef lo consultó con Julián (Miami) por videollamada en la reunión y
  # quedaron en que no se puede guardar bajo el tipo equivocado:
  #
  #   > "No te va a permitir grabarlo. No vas a poder hacerlo... el chavo no
  #   >  hizo nada, no pudo hacer nada."
  #
  # El cambio de servicio (PR-C6.8) es la **excepción explícita**: ahí el
  # operario declaró que el paquete sale de la sesión, así que no hay
  # conflicto que reportar.
  def conflicto_con_la_sesion(paquete)
    return nil if paquete.solicito_cambio_servicio?

    tipo_pa = tipo_envio_de_la_pre_alerta(paquete.tracking)
    return nil if tipo_pa.nil?
    return nil if tipo_pa.id == @tipo_envio_sesion.id

    "Este paquete tiene pre-alerta de #{tipo_pa.nombre} y estás trabajando " \
    "#{@tipo_envio_sesion.nombre}. Finalizá la sesión y abrí una de " \
    "#{tipo_pa.nombre}, o marcá cambio de servicio."
  end

  # El tipo de envío que el cliente pidió en su pre-alerta, si hay una sin
  # vincular con este tracking.
  def tipo_envio_de_la_pre_alerta(tracking)
    return nil if tracking.blank?

    # PR-C6.21: misma escalera que el resto del escaneo. Si acá no encuentra la
    # pre-alerta, el aviso de "este paquete es de otro tipo de envío" no sale y
    # el paquete se graba bajo el servicio equivocado — eso es plata.
    PreAlertaPaquete.sin_vincular
                    .buscar_escaneado(tracking)
                    .includes(:pre_alerta)
                    .first&.pre_alerta&.tipo_envio
  end

  # El paquete que se está actualizando, si vino por `?paquete_id=`.
  def paquete_a_actualizar
    return nil if params[:paquete_id].blank?

    Paquete.find_by(id: params[:paquete_id])
  end

  # ¿El form pide cambiar la cantidad de cajas de verdad? Mismo criterio que
  # `PaquetesController`: solo cuando ya es un split o pasa a serlo.
  # ¿El paquete que se está actualizando es de otro servicio que el de la sesión?
  #
  # Es **otra pregunta** que la de `conflicto_con_la_sesion`, que mira el tipo que
  # pidió la **pre-alerta** — sirve al dar de alta, cuando el paquete todavía no
  # tiene tipo propio. Acá el paquete ya existe y tiene el suyo, que es
  # justamente lo que Yusef vio: *"es exprés y me está dejando actualizar en
  # CER"*.
  #
  # Devuelve el texto del aviso, o nil. **No bloquea**: corregirle el peso a un
  # CEM desde una sesión CER no puede convertirlo en CER ni puede impedirse.
  def aviso_de_tipo_distinto(paquete)
    return nil if @tipo_envio_sesion.nil? || paquete.tipo_envio_id.nil?
    return nil if paquete.tipo_envio_id == @tipo_envio_sesion.id

    "Ojo: es de #{paquete.tipo_envio.nombre} y estás trabajando " \
    "#{@tipo_envio_sesion.nombre}."
  end

  # El aviso que ve el que actualizó. Lleva pegado el del tipo de envío distinto
  # cuando lo hay — no bloquea el guardado, pero tiene que enterarse.
  def aviso_de_actualizacion
    base = "Paquete #{@paquete.tracking} actualizado."
    @aviso_de_otro_tipo.present? ? "#{base} #{@aviso_de_otro_tipo}" : base
  end

  # Cuántas cajas pidió el que está actualizando.
  #
  # Yusef, 2026-08-19: *"le digo que son dos etiquetas… solo te va a tirar una"*,
  # y *"le di cinco y se quedó con las primeras tres"*.
  #
  # Esto leía `paquete_params[:cantidad_paquetes]`, un campo que `A7-20` **quitó
  # del formulario**, y nunca miraba el `etiquetas` que manda el modal de
  # `PR-C7.23`. O sea que `ajustar_split!` no se llamaba nunca y la respuesta del
  # operario se tiraba en silencio.
  #
  # El `cantidad_paquetes` se sigue leyendo primero por si alguna pantalla vuelve
  # a mandarlo; hoy no lo manda ninguna.
  #
  # **Si no vino ninguno de los dos, devuelve 0 y no se toca nada.** Ojo con esto:
  # `etiquetas_pedidas` contesta `1` cuando el parámetro falta —que es lo correcto
  # al dar de alta—, y ese `1` acá significaría "bajá este envío a una sola caja".
  # Guardar un split de tres sin tocar la cantidad le borraría dos.
  def cantidad_de_cajas_pedida
    return paquete_params[:cantidad_paquetes].to_i if paquete_params.key?(:cantidad_paquetes)
    return 0 if params[:etiquetas].blank?

    etiquetas_pedidas.to_i
  end

  def ajusta_cajas?(nueva_cantidad)
    return false if nueva_cantidad < 1

    actual = @paquete.cantidad_paquetes.to_i
    return false if nueva_cantidad == actual

    actual > 1 || nueva_cantidad > 1
  end

  def authorize_etiquetar
    require_role(:supervisor_miami, :digitador_miami)
  end

  # Tipo de envío activo del lote (puede ser nil → la vista muestra el prompt).
  def load_tipo_envio_sesion
    @tipo_envio_sesion = TipoEnvio.activos.find_by(id: session[:etiquetar_tipo_envio_id])
    session.delete(:etiquetar_tipo_envio_id) if @tipo_envio_sesion.nil?

    @sucursal_recepcion_sesion = Sucursal.find_by(id: session[:etiquetar_sucursal_recepcion_id])
    # Sesiones abiertas antes de PR-C6.5 no traen sucursal. En vez de
    # obligarlos a cerrar y volver a abrir en medio de un lote, se cae al
    # default — que es la misma sucursal donde ya estaban recibiendo.
    @sucursal_recepcion_sesion ||= sucursal_recepcion_por_defecto if @tipo_envio_sesion
  end

  # Las sucursales donde se **recibe** carga (`Sucursal.de_recepcion`, el
  # checkbox de /sucursales). Hoy es Miami sola y la vista no pregunta nada; el
  # día que abran Panamá o México aparece el select sin tocar código.
  #
  # C18-02: esto filtraba por la **ubicación del usuario** —"quien recibe está
  # parado en un lugar"— y el admin de Yusef está en Honduras: le ofrecía San
  # Pedro, Tegucigalpa y San Manuel y le escondía Miami. *"¿Dónde se está
  # recibiendo el paquete? No es a dónde va… el que está oculto es el que va a
  # recibir."* El número de recepción de su etiqueta salió `RSPS…` por lo mismo.
  # El guard del prefijo se fue con él: la columna es `NOT NULL` y el número
  # sale de `Sucursal#codigo` desde RP-17.
  def sucursales_recepcion_posibles
    Sucursal.de_recepcion.to_a
  end

  # Dónde recibe este usuario cuando no eligió: la regla vive en `Sucursal`
  # porque /entrega_personal la comparte (seguimiento de C18-02, 2026-08-27).
  def sucursal_recepcion_por_defecto
    Sucursal.recepcion_por_defecto_para(Current.user, entre: sucursales_recepcion_posibles)
  end

  # No se puede etiquetar sin un tipo de envío de sesión activo.
  def require_tipo_envio_sesion
    return if @tipo_envio_sesion

    redirect_to etiquetar_path, alert: "Iniciá una sesión de etiquetado primero."
  end

  def paquetes_hoy_count
    Paquete.where(user: Current.user)
      .where(fecha_recibido_miami: Time.current.beginning_of_day..Time.current.end_of_day)
      .count
  end

  # Vincula y devuelve cuántas. El correo ya no sale de acá: lo manda
  # `notificar_recibido` (C18-06), un solo sitio, para que un paquete
  # pre-alertado y con política no reciba dos.
  def link_pre_alertas(paquete)
    PreAlertaPaquete.link_tracking!(paquete.tracking, paquete)
  end

  def paquete_params
    # tipo_envio_id NO se permite aquí: lo fija la sesión de etiquetado.
    params.require(:paquete).permit(
      :tracking, :tracking_secundario, :cliente_id, :tercero_id, :tercero_nombre, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :expedido_por,
      :notas_internas, :notas_retencion,
      :solicito_cambio_servicio, :retener_miami,
      :enviado_por_politica, :notas_envio_politica,
      motivo_retencion_ids: [], motivo_envio_politica_ids: []
    )
  end

  # PR-C6.11: `pre_factura_flag_param` vivía acá. Se fue con los checkboxes de
  # Pre-Alerta y Pre-Factura que Yusef mandó sacar de /etiquetar — "esto no
  # tiene nada que ver con ellos". Dejar el lector de un param que nadie manda
  # solo confunde al que venga después.
  # `proveedor` (string legacy) Y a la vez el name de la asociación
  # belongs_to :proveedor (PR-D3.a catálogo). Mismo conflicto que pre_factura:
  # asignar un string desde el form dispara AssociationTypeMismatch. Se escribe
  # vía column accessor `paquete[:proveedor]`. La asociación se usa solo cuando
  # hay un Proveedor del catálogo (via proveedor_id en otros flows).
  def proveedor_string_param
    return :missing unless params.dig(:paquete)&.key?(:proveedor)

    params[:paquete][:proveedor].to_s
  end
end
