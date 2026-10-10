class ManifiestosController < ApplicationController
  include CandadoDelManifiesto
  # `buscar` (JSON) lo usan operadores que editan paquetes pero no
  # necesariamente tienen rol de Miami — se gatea via authorize_edit
  # del paquete antes de llegar acá.
  before_action :authorize_manifiestos, except: [ :buscar ]
  before_action :set_manifiesto, only: %i[show edit update add_paquete empacar_sin_escanear remove_paquete finalizar documento listado escanear mover_paquete
                                          abrir_edicion cerrar_edicion escanear_para_quitar]
  # C30-06 · Lo de adentro solo se toca con el manifiesto abierto, o reabierto
  # con «Editar» por un supervisor. Ver `CandadoDelManifiesto`.
  before_action :exigir_modificable, only: %i[add_paquete escanear mover_paquete empacar_sin_escanear
                                              remove_paquete escanear_para_quitar]

  def index
    @manifiestos = Manifiesto.activos.includes(:empresa_manifiesto).order(created_at: :desc)
    @manifiestos = @manifiestos.buscar(params[:q]) if params[:q].present?
    @manifiestos = @manifiestos.by_estado(params[:estado]) if params[:estado].present?
    @manifiestos = @manifiestos.page(params[:page]).per(per_page_sanitized)
  end

  # PR-C30.15 · «Editar» edita **acá**, en la misma ficha. Jorge, 2026-10-10:
  # *"it really don't make sense pressing editar sends me here [/edit], I want
  # to edit the current view plus all what is in the manifiesto, something
  # like this view /manifiestos/24"*. La tarjeta «Detalles del Manifiesto» es
  # un Turbo Frame (`manifiesto-detalles`) que se da vuelta a formulario; las
  # casas y los paquetes ya se editaban en la ficha.
  #
  # Tres formas de llegar:
  # - el frame pide la ficha («Cancelar» adentro del formulario) → la tarjeta
  #   de solo lectura, sola;
  # - `?editar=1` (el pencil de la lista, o recién abierto el candado) → la
  #   ficha entera con la tarjeta ya en formulario, si el usuario puede;
  # - lo demás → la ficha de siempre.
  def show
    if frame_de_detalles?
      render partial: "manifiestos/detalles", locals: { manifiesto: @manifiesto, editando: false }
      return
    end

    cargar_contenido
    @editando = params[:editar].present? && @manifiesto.encabezado_editable_por?(Current.user)
    assigns_del_formulario if @editando
  end

  def new
    @manifiesto = Manifiesto.new
    assigns_del_formulario
  end

  def create
    # PR-C30.14 · Lo de San Pedro se acepta al editar, no al crear: un
    # manifiesto que se está armando no salió de Miami, y el formulario de
    # alta no lo muestra.
    atributos = manifiesto_params.except(*Manifiesto::CAMPOS_DE_SAN_PEDRO)
    @manifiesto = Manifiesto.new(atributos)
    @manifiesto.sucursal_origen_id = sucursal_origen_para(atributos)
    @manifiesto.user = Current.user

    if @manifiesto.save
      redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} creado exitosamente."
    else
      assigns_del_formulario
      render :new, status: :unprocessable_entity
    end
  end

  # PR-C30.15 · Ya no es una pantalla. Adentro del frame devuelve la tarjeta
  # en formulario; pedido entero (el lápiz de la lista, un link guardado) va a
  # la ficha con la tarjeta abierta. PR-C30.14 había hecho de /edit el
  # manifiesto entero, y eso es lo que Jorge no quiso: dos pantallas para lo
  # mismo.
  def edit
    return if exigir_encabezado_editable

    if frame_de_detalles?
      assigns_del_formulario
      render partial: "manifiestos/detalles", locals: { manifiesto: @manifiesto, editando: true }
    else
      redirect_to manifiesto_path(@manifiesto, editar: 1)
    end
  end

  # Lo que llena San Pedro también se guarda desde acá (PR-C30.14), con el
  # mismo candado que el encabezado. `estampar_recibido_hn_por` sella a quien
  # guarda la fecha: si la corrige un supervisor de Miami desde esta pantalla,
  # él queda como «recibido por». Se acepta: es quien puso la fecha que está
  # (la misma regla que en `/guias-y-aduana`).
  #
  # PR-C30.15 · Guardar vuelve **a la misma ficha**: la tarjeta pasa a solo
  # lectura y lo demás se refresca en el lugar (los botones de cierre y lo de
  # adentro, porque «Empacar sin escanear (N)» depende de los tipos). Un error
  # vuelve a pintar el formulario adentro del frame, con 422.
  def update
    return if exigir_encabezado_editable

    # Sin `tipo`: oficial o interno se elige al crear (`A7-07`), y la tarjeta
    # no lo manda (en /edit iba como hidden). El permit igual lo dejaba cambiar
    # con un PATCH armado a mano.
    if @manifiesto.update(manifiesto_params.except(:tipo))
      mensaje = "Manifiesto actualizado exitosamente."
      respond_to do |format|
        format.turbo_stream do
          @manifiesto.reload
          cargar_contenido
          render turbo_stream: [
            # `replace` y no `update`: el `<turbo-frame>` vive adentro del
            # partial (lo necesita el frame que pide `edit`), así que un
            # `update` lo anidaría adentro de sí mismo.
            turbo_stream.replace("manifiesto-detalles", partial: "manifiestos/detalles",
                                                        locals: { manifiesto: @manifiesto, editando: false }),
            turbo_stream.update("manifiesto-contenido", partial: "manifiestos/contenido",
                                                        locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
            *streams_del_manifiesto,
            turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: mensaje })
          ]
        end
        format.html { redirect_to @manifiesto, notice: mensaje }
      end
    else
      assigns_del_formulario
      if frame_de_detalles?
        render partial: "manifiestos/detalles", locals: { manifiesto: @manifiesto, editando: true },
               status: :unprocessable_entity, formats: [ :html ]
      else
        # Sin Turbo (o un pedido armado a mano): la ficha entera con la
        # tarjeta abierta y el error, no un pedazo suelto sin layout.
        cargar_contenido
        @editando = true
        render :show, status: :unprocessable_entity, formats: [ :html ]
      end
    end
  end

  # C29-07 · Agregar pasa por las mismas preguntas que el escaneo. Hasta acá
  # confiaba en que la pantalla solo lo llamara con un `ok`, así que la regla
  # vivía en el JS: un pedido armado a mano —o una pantalla vieja abierta en
  # otra pestaña— metía un CKA en un manifiesto CER, o un paquete de Humuya en
  # uno que va a San Pedro. Una regla, todas las puertas.
  def add_paquete
    paquete = Paquete.find(params[:paquete_id])
    resultado = EscaneoDeManifiesto.new(@manifiesto).clasificar(paquete)
    unless resultado.ok?
      return respond_to_paquete_change("#{paquete.guia} no se agregó: #{motivo_del_escaneo(resultado)}", tipo: :alert)
    end

    # C30-06 · `meter!` y no un `update!` suelto: en un manifiesto finalizado
    # y reabierto el paquete tiene que salir como los demás, a enviado.
    @manifiesto.meter!(paquete, user: Current.user)
    respond_to_paquete_change("Paquete #{paquete.guia} agregado al manifiesto.")
  rescue Manifiesto::NoEntra => e
    respond_to_paquete_change(e.message, tipo: :alert)
  end

  # C28-04 · Lo que leyó la pistola, **y por qué** entra o no. Solo clasifica
  # (`EscaneoDeManifiesto`); el que escribe sigue siendo `add_paquete`, que la
  # pantalla llama cuando la respuesta es `ok`, o `mover_paquete` cuando el
  # operario confirma el modal de «está en otro manifiesto».
  #
  # `paquete_id` en vez de `codigo` es la lista de resultados: el operario
  # eligió uno y pasa por las mismas preguntas que si lo hubiera escaneado.
  def escanear
    escaneo = EscaneoDeManifiesto.new(@manifiesto)
    codigo = params[:codigo].to_s.strip
    resultado =
      if params[:paquete_id].present?
        escaneo.clasificar(Paquete.includes(:cliente, :tipo_envio, :manifiesto).find(params[:paquete_id]))
      else
        escaneo.por_codigo(codigo)
      end

    render json: respuesta_del_escaneo(resultado, codigo)
  end

  # C28-04 · *"¿Desea agregar este a este manifiesto y retirarlo del otro?"*
  #
  # Solo desde un manifiesto que **sigue abierto** (Jorge, 2026-10-04): uno ya
  # enviado se firmó y viajó, y sacarle un paquete sería cambiar un papel que
  # ya no está en la mano. Al salir del otro se le suelta la caja —la etiqueta
  # 4×6 de esa caja ya no lo cuenta— y vuelve al estado de recién etiquetado,
  # que es lo mismo que hace `remove_paquete`. Los dos manifiestos recalculan.
  def mover_paquete
    paquete = Paquete.find(params[:paquete_id])
    resultado = EscaneoDeManifiesto.new(@manifiesto).clasificar(paquete)
    unless resultado.tipo == :en_otro
      return respond_to_paquete_change("#{paquete.guia} no se movió: #{motivo_del_escaneo(resultado)}", tipo: :alert)
    end

    otro = paquete.manifiesto
    Paquete.transaction do
      # C30-06 · Por `meter!`, como `add_paquete`: si éste es uno finalizado y
      # reabierto, el que llega sale a enviado con los demás.
      @manifiesto.meter!(paquete, user: Current.user, caja_manifiesto: nil,
                                  estado: @manifiesto.estado_antes_de_salir)
      otro.recalculate_totals!
    end
    respond_to_paquete_change("#{paquete.guia} se movió del manifiesto #{otro.numero} a éste.")
  rescue Manifiesto::NoEntra => e
    respond_to_paquete_change(e.message, tipo: :alert)
  end

  # C23-10 · El mismo `add_paquete`, pero de un tirón y sin pistola.
  #
  #   > "No les da chance de escanear y le empacan al puro… meten todo."
  #   > "Todos los paquetes que tienen el estatus [recibido en Miami], que bajo
  #   >  el tipo de servicio que se seleccionó para este [manifiesto]…
  #   >  automáticamente se va a enviar sin escanear."
  #
  # Cuando no hay ninguno **se dice por qué**, nombrando los tres filtros. Un
  # redirect callado dejaría al operario mirando la misma pantalla sin saber si
  # el botón hizo algo, si falló, o si de verdad no había carga.
  def empacar_sin_escanear
    servicio = EmpacarSinEscanear.new(@manifiesto, user: Current.user)

    unless servicio.aplica?
      redirect_to manifiesto_path(@manifiesto), alert: "Este manifiesto no admite empacar sin escanear."
      return
    end

    resultado = servicio.call

    if resultado.ninguno?
      # El estado sale del servicio y no escrito a mano: en el oficial es
      # «recibido en Miami» y en el interno «disponible para entrega», y el
      # aviso tiene que nombrar el que de verdad se buscó (`C23-14`).
      redirect_to manifiesto_path(@manifiesto),
                  alert: "No hay paquetes para agregar. Entran los que están en " \
                         "«#{estado_legible(servicio.estado_buscado)}», del tipo " \
                         "#{@manifiesto.tipos_envio_nuestros}, en " \
                         "#{@manifiesto.sucursal_origen&.nombre || "—"} y todavía sin manifiesto."
      return
    end

    redirect_to manifiesto_path(@manifiesto), notice: "Entraron #{resultado.agregados} paquete(s) sin escanear."
  end

  # El rótulo del estado tal como lo ve el operario, del **mismo mapa** que pinta
  # las insignias en toda la app: escribir «Recibido en Miami» a mano acá sería
  # tenerlo en dos lugares y dejar que se separen.
  def estado_legible(estado)
    EstadoPaqueteHelper::ETIQUETAS.fetch(estado, estado.humanize)
  end

  def remove_paquete
    paquete = @manifiesto.paquetes.find(params[:paquete_id])
    # PR-C6.22: sacar del manifiesto devuelve a **recibido**, no a empacado.
    # C30-06 · Y desde uno finalizado y reabierto, deshace también el enviado:
    # *"eliminar paquetes que no se fueron"*. Todo eso vive en
    # `Manifiesto#sacar!`, que usan también el escaneo para quitar.
    @manifiesto.sacar!(paquete)
    respond_to_paquete_change("Paquete #{paquete.guia} removido del manifiesto.")
  rescue Manifiesto::NoSeSaca => e
    # PR-C30.14 · Tiene pre-factura o medición: no sale, y se dice por qué. Con
    # 422 y no 200: el modal de «Eliminar paquetes» cuenta como sacado todo lo
    # que vuelve bien, y éste no salió.
    respond_to_paquete_change(e.message, tipo: :alert, status: :unprocessable_entity)
  end

  # C30-06 · «Eliminar paquetes», escaneando. Yusef: *"deseo eliminar paquetes,
  # y le vas a decir que sí, y empezás a escanear clac, clac, clac"* · *"que
  # diga agregar paquetes o que diga eliminar paquetes que no se fueron, y
  # entonces empezás a escanear en un modal"*.
  #
  # Igual que el de agregar, esto **solo clasifica** (`EscaneoDeManifiesto#
  # para_quitar`): el que escribe es `remove_paquete`, que la pantalla llama
  # cuando la respuesta es `ok`. Una puerta de escritura por acción.
  def escanear_para_quitar
    codigo = params[:codigo].to_s.strip
    resultado = EscaneoDeManifiesto.new(@manifiesto).para_quitar(codigo)
    paquete = resultado.paquete

    mensaje =
      case resultado.tipo
      when :ok then "#{codigo_de(paquete)} · #{paquete.tracking} sale del manifiesto."
      when :no_se_saca then @manifiesto.motivo_para_no_sacar(paquete)
      when :varios then "«#{codigo}» trae #{resultado.candidatos.size} cajas de este manifiesto: escaneá la etiqueta de la caja que no se fue."
      when :no_esta_aca
        donde = paquete.manifiesto ? "está en el manifiesto #{paquete.manifiesto.numero}" : "no está en ningún manifiesto"
        "#{codigo_de(paquete)} no está en este manifiesto: #{donde}."
      else "No existe ningún paquete con «#{codigo}»."
      end

    cuerpo = { resultado: resultado.tipo.to_s, mensaje: mensaje }
    cuerpo[:paquete_id] = paquete.id if resultado.ok?
    render json: cuerpo
  end

  # C30-06 · «Editar» sobre un manifiesto finalizado: abre lo de adentro.
  # *"Que presionen el botón, para que nadie toque algo que no era."*
  #
  # PR-C30.15 · Y aterriza con la tarjeta del encabezado **ya en formulario**
  # (`?editar=1`): el supervisor apretó «Editar» una vez, y lo que se abre es
  # el manifiesto entero —encabezado, casas y paquetes—, en la misma ficha.
  def abrir_edicion
    @manifiesto.abrir_edicion!(Current.user)
    redirect_to manifiesto_path(@manifiesto, editar: 1),
                notice: "#{@manifiesto.numero} quedó abierto para corregir. Cuando termines, «Cerrar edición»."
  rescue Manifiesto::NoSePuedeReabrir => e
    redirect_to manifiesto_path(@manifiesto), alert: e.message
  end

  # Y se vuelve a bloquear. Lo cierra quien lo puede abrir.
  def cerrar_edicion
    unless @manifiesto.editable_por?(Current.user)
      return redirect_to manifiesto_path(@manifiesto),
                         alert: "Solo #{Manifiesto::QUIEN_ABRE_EL_CANDADO} puede cerrar la edición."
    end

    @manifiesto.cerrar_edicion!
    redirect_to manifiesto_path(@manifiesto), notice: "#{@manifiesto.numero} quedó bloqueado otra vez."
  end

  # C21-06 · «Solo Finalizar» y «Finalizar e Imprimir». Los paquetes de los
  # tipos seleccionados pasan a ENVIADO, uno por uno; los que tienen una tarea
  # abierta no pasan y salen listados, sin trabar a los demás — la misma forma
  # que `A7-05` eligió para la recepción parcial.
  def finalizar
    resultado = @manifiesto.finalizar!(user: Current.user)

    # C21-06 · Jorge, 2026-08-30: *"bloquear cierre"*. Un paquete trabado no
    # deja finalizar a ninguno — el manifiesto queda igual que estaba y hay que
    # resolver la tarea antes de volver a darle.
    if resultado.bloqueado?
      trabados = resultado.trabados.map { |paquete, motivo| "#{paquete.numero_recepcion_visible} (#{motivo})" }
      redirect_to @manifiesto,
                  alert: "No se finalizó #{@manifiesto.numero}: #{resultado.trabados.size} paquete(s) con tareas abiertas. #{trabados.join(' · ')}"
      return
    end

    aviso = "Manifiesto #{@manifiesto.numero} finalizado: #{resultado.enviados.size} paquete(s) a enviado."

    # C30-05 · Lo que sale es **la hoja del manifiesto**, no las 4×6. Cambia
    # `C21-06`, que había leído del diagrama *"finalizar e imprimir todos los
    # bultos"*. Yusef, 2026-10-09, probándolo en staging: *"lo que tiene que
    # imprimirme no es esta etiqueta… el que necesito que me imprima después de
    # finalizado es este. Este es el que ellos imprimen después de finalizado,
    # porque todas esas etiquetas ya las imprimieron cuando los estaban
    # ingresando"* — y al darle otra vez: *"me está imprimiendo ésta otra vez"*.
    # Las 4×6 se siguen re-imprimiendo aparte, con «Imprimir las 4×6».
    #
    # Ya no depende de que haya cajas: la hoja sale igual sin bultos (el
    # manifiesto que se armó sin escanear, `C23-10`), con transportista, totales
    # y firmas, que es lo que el transportista se lleva.
    #
    # PR-C29.7 · Con `volver=1`, como «Agregar e imprimir»: esto nace de un
    # PATCH y se lleva **esta** pestaña, así que al terminar no hay nada que
    # cerrar —`window.close()` sobre una pestaña que no abrió un script no hace
    # nada— y hay que devolverla a la ficha. Jorge: *"una vez se imprime se
    # regresa a la vista previa"*. `documento` lo honra igual que las 4×6.
    if params[:imprimir].present?
      redirect_to documento_manifiesto_path(@manifiesto, print: true, volver: 1), notice: aviso
    else
      redirect_to @manifiesto, notice: aviso
    end
  rescue ArgumentError => e
    redirect_to @manifiesto, alert: e.message
  end

  # C21-09 · El manifiesto impreso. Las cuatro correcciones que Yusef anotó a
  # mano sobre las dos copias del legacy viven en la vista; acá solo se arma la
  # data. El `layout: "print"` es el mismo del Warehouse Receipt, que trae de
  # regalo la cadena de `?print=true` (imprime y, con `cerrar=1`, se cierra).
  #
  # C28-01 · Ya no lleva los paquetes: esta hoja se le entrega al transportista.
  # El desglose se fue a `listado`.
  #
  # C30-05 · `volver=1` cuando la abre «Finalizar e Imprimir», que se lleva la
  # pestaña de la ficha: al terminar de imprimir la devuelve, igual que
  # `CajasManifiestoController#etiquetas`. Un flag y no la URL de vuelta en el
  # parámetro, que sería un redirect abierto de regalo.
  def documento
    @cajas = @manifiesto.cajas.includes(:tamano_caja)
    @despues_de_imprimir = manifiesto_path(@manifiesto) if params[:volver] == "1"
    render layout: "print"
  end

  # C28-02 · El desglose de paquetes, **aparte** de la hoja que viaja con la
  # carga. Yusef: *"el listado sí va amarrado, pero no va en la impresión. Eso
  # lo sacamos aparte"*. Es interno: sin transportista y sin firmas.
  #
  # Va ordenado **por bulto**, que es como se revisa contra la carga: abrir la
  # caja A y tachar lo que tiene adentro. Lo que entró sin pistola (`C23-10`)
  # no tiene bulto y va al final.
  def listado
    @paquetes = @manifiesto.paquetes.includes(:cliente, :tipo_envio, :caja_manifiesto).to_a
                           .sort_by { |p| orden_en_el_listado(p) }
    render layout: "print"
  end

  # Endpoint JSON para el autocomplete del manifiesto en el form del paquete.
  def buscar
    q = params[:q].to_s.strip
    scope = Manifiesto.activos.includes(:sucursal_origen).order(created_at: :desc).limit(10)
    scope = scope.buscar(q) if q.present?
    render json: scope.map { |m|
      {
        id: m.id,
        numero: ERB::Util.html_escape(m.numero),
        estado: ERB::Util.html_escape(m.estado.to_s),
        fecha_enviado: m.fecha_enviado&.strftime("%d/%m/%Y %H:%M"),
        sucursal: ERB::Util.html_escape(m.sucursal_origen&.codigo.to_s),
        paquetes_count: m.paquetes.count
      }
    }
  end

  # C21-02 · Esta pantalla es **de Miami**. Lo que llena San Pedro se fue a
  # `/guias-y-aduana` (`PR-U1`), así que acá no hay dos mitades que separar:
  # `SOLO_MIAMI` y el segundo `before_action` que hacían falta para eso se
  # fueron con la sección.
  private def authorize_manifiestos
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:manifiestos)
  end

  private def respuesta_del_escaneo(resultado, codigo)
    paquete = resultado.paquete
    base = { resultado: resultado.tipo.to_s, mensaje: motivo_del_escaneo(resultado, codigo) }
    base[:paquete] = paquete_del_escaneo(paquete) if paquete
    base[:otro_manifiesto] = resultado.otro_manifiesto&.numero if paquete&.manifiesto_id
    base[:paquetes] = resultado.candidatos.map { |p| paquete_del_escaneo(p) } if resultado.candidatos
    base
  end

  private def paquete_del_escaneo(paquete)
    { id: paquete.id,
      codigo: codigo_de(paquete),
      tracking: paquete.tracking,
      cliente: paquete.cliente&.nombre_completo,
      cliente_codigo: paquete.cliente&.codigo,
      peso_cobrar: paquete.peso_cobrar.to_f,
      manifiesto: paquete.manifiesto&.numero }
  end

  # Las frases son las de Yusef cuando las dijo; las demás, en su mismo tono.
  private def motivo_del_escaneo(resultado, codigo = nil)
    paquete = resultado.paquete
    case resultado.tipo
    when :ok
      "#{codigo_de(paquete)} · #{paquete.tracking} agregado."
    when :en_este
      "Este paquete ya fue escaneado y está en este manifiesto (#{codigo_de(paquete)})."
    when :en_otro
      "#{codigo_de(paquete)} ya fue escaneado y está en el manifiesto #{paquete.manifiesto.numero}."
    when :en_otro_cerrado
      "#{codigo_de(paquete)} está en el manifiesto #{paquete.manifiesto.numero}, que ya salió " \
        "(#{paquete.manifiesto.estado.humanize.downcase}). No se puede mover."
    when :tipo_distinto
      "#{codigo_de(paquete)} es #{paquete.tipo_envio&.nombre || "sin tipo"}, " \
        "y este manifiesto lleva #{@manifiesto.tipos_envio_nuestros}."
    when :sucursal_distinta
      "#{codigo_de(paquete)} retira en #{paquete.sucursal.nombre}, " \
        "y este manifiesto va a #{@manifiesto.sucursal_entrega.nombre}."
    when :fuera_de_circulacion
      "#{codigo_de(paquete)} está #{estado_legible(paquete.estado).downcase}: ya no viaja."
    when :varios
      "«#{codigo}» trae #{resultado.candidatos.size} cajas que no están en este manifiesto: elegí cuál."
    else
      "No existe ningún paquete con «#{codigo}»."
    end
  end

  private def codigo_de(paquete)
    helpers.etiqueta_codigo_barras(paquete) || paquete.tracking
  end

  private def orden_en_el_listado(paquete)
    caja = paquete.caja_manifiesto
    [ caja ? CajaManifiesto.numero_para(caja.letra).to_i : Float::INFINITY,
      paquete.numero_recepcion.to_s, paquete.numero_caja.to_i, paquete.id ]
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  # Lo que pintan las casas y la tabla de paquetes (`manifiestos/_contenido`).
  # Una sola carga para la ficha y el turbo_stream de cada cambio (PR-C30.14):
  # eran dos copias de la misma precarga.
  private def cargar_contenido
    # C21-04: los tamaños pre-definidos con los que se arma una casa.
    @tamanos = TamanoCaja.activos.ordered
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino, :caja_manifiesto).order(:created_at)
    # PR-C29.20 · La tabla de casas pinta, por cada caja, su tamaño y los tipos
    # de envío que lleva adentro (`CajaManifiesto#tipos_envio_adentro`, que
    # recorre sus paquetes). Sin precargar eran dos consultas por caja: con 15
    # cajas la ficha pasaba de 27 consultas a 39.
    ActiveRecord::Associations::Preloader.new(
      records: [ @manifiesto ], associations: { cajas: [ :tamano_caja, { paquetes: :tipo_envio } ] }
    ).call
  end

  def respond_to_paquete_change(message, tipo: :notice, status: :ok)
    # C30-07 · La tabla de casas dice qué lleva cada una: si un paquete entra o
    # sale, esa columna también cambia. Misma carga que `show`.
    @manifiesto.reload
    cargar_contenido
    respond_to do |format|
      format.turbo_stream do
        # PR-C30.15 · La tarjeta del encabezado **no** se reemplaza acá: puede
        # estar abierta en formulario, con algo tecleado, y escanear un paquete
        # no puede borrárselo. Sus dos números (paquetes y peso) llegan por su
        # id en `streams_del_manifiesto`.
        render status: status, turbo_stream: [
          turbo_stream.update("manifiesto-paquetes", partial: "manifiestos/paquetes_table", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.update("manifiesto-cajas-tabla", partial: "manifiestos/cajas_tabla",
                                                        locals: { manifiesto: @manifiesto,
                                                                  editable: @manifiesto.modificable_por?(Current.user) }),
          *streams_del_manifiesto,
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { tipo => message })
        ]
      end
      format.html { redirect_to manifiesto_path(@manifiesto), tipo => message }
    end
  end

  # PR-C30.15 · Lo que cambia en la ficha cada vez que cambia el manifiesto, lo
  # cambie un paquete (`respond_to_paquete_change`) o el encabezado (`update`).
  # Una lista sola para que las dos respuestas no se separen.
  private def streams_del_manifiesto
    [
      # C21-06 · Los botones de cierre **también**. Se actualizaba solo la
      # tabla, y como «Solo Finalizar» solo se dibuja con `paquetes.any?`, al
      # agregar el primer paquete la tabla se llenaba y el botón no aparecía:
      # la única forma de finalizar era recargar la pantalla. Y al quitar el
      # último pasa al revés — el botón quedaba ofreciendo finalizar un
      # manifiesto vacío.
      # Van los dos: el bloque está arriba y abajo porque con la tabla llena el
      # de arriba queda a una pantalla de distancia. Refrescar uno solo dejaría
      # al otro mintiendo.
      turbo_stream.update("manifiesto-acciones-arriba", partial: "manifiestos/acciones", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
      turbo_stream.update("manifiesto-acciones-abajo", partial: "manifiestos/acciones", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
      # Los dos números de la tarjeta, por su id: están en las dos caras de la
      # tarjeta (solo lectura y formulario), así que el escaneo los sube sin
      # tocar lo que se está tecleando.
      turbo_stream.update("manifiesto-detalles-paquetes", @manifiesto.cantidad_paquetes.to_s),
      turbo_stream.update("manifiesto-detalles-peso", helpers.peso_total_del_manifiesto(@manifiesto))
    ]
  end

  # PR-C30.15 · ¿El pedido viene del frame de la tarjeta? Se pregunta **por su
  # id** y no con `turbo_frame_request?` a secas: la ficha tiene otro frame
  # (`manifiesto-paquetes`), y lo que pida desde ahí no puede recibir esta
  # tarjeta.
  private def frame_de_detalles?
    request.headers["Turbo-Frame"] == "manifiesto-detalles"
  end

  # PR-C30.15 · El candado del encabezado (`Manifiesto#encabezado_editable_por?`),
  # para `edit` y `update`. Devuelve true si ya contestó que no.
  private def exigir_encabezado_editable
    return false if @manifiesto.encabezado_editable_por?(Current.user)

    mensaje =
      if @manifiesto.reabrible?
        @manifiesto.motivo_del_candado
      else
        "#{@manifiesto.numero} está finalizado: solo #{Manifiesto::QUIEN_ABRE_EL_CANDADO} puede corregir el encabezado."
      end
    negar_por_el_candado(mensaje)
    true
  end

  # C21-02 · Lo que la pantalla puede mandar. Las columnas viejas `tipo_envio`,
  # `numero_guia` y `numero_caja` **salen de acá**: dejan de escribirse y quedan
  # solo para leer lo que ya está grabado.
  # C21-06 · El candado. Un manifiesto cerrado solo lo reabre quien puede
  # (`Manifiesto#editable_por?`), y el que no puede **se entera**: se le contesta
  # con un aviso, no se le acepta el formulario para descartárselo callado, que
  # es lo que pasaba mientras las dos mitades compartían pantalla.
  def manifiesto_params
    params.require(:manifiesto).permit(
      :numero, :empresa_manifiesto_id,
      # El encabezado que Yusef anotó campo por campo sobre el impreso.
      :consignatario_id, :tipo_envio_proveedor_id, :sucursal_entrega_id, :es_prioridad,
      # `sucursal_origen_id` es lo que despierta la numeración anual. Estaba
      # fuera de esta lista, y por eso `MM2026000001` no corría nunca (RP-46).
      :sucursal_origen_id,
      # `A7-07` · Oficial o interno. Solo al crear: `update` lo descarta, porque
      # el número ya salió y la carga ya se movió con las reglas de su tipo.
      :tipo,
      # PR-C30.14 · Lo de San Pedro, que /edit también muestra. Son los
      # mismos dos de `/guias-y-aduana` (`Manifiesto::CAMPOS_DE_SAN_PEDRO`).
      :fecha_aduana,
      tipo_envio_ids: [],
      guias_attributes: %i[id numero position _destroy]
    )
  end

  # C21-02 · La sucursal de origen es lo que le da número anual al manifiesto.
  # Si la pantalla no la manda, se usa la misma regla que /etiquetar y
  # /entrega_personal — vive en `Sucursal` justamente para que no se separen.
  def sucursal_origen_para(atributos)
    return atributos[:sucursal_origen_id] if atributos[:sucursal_origen_id].present?

    Sucursal.recepcion_por_defecto_para(Current.user)&.id
  end

  def assigns_del_formulario
    @empresas          = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios       = TipoEnvio.activos.order(:nombre)
    @tipos_proveedor   = TipoEnvioProveedor.activos.ordered
    @consignatarios    = Consignatario.activos.ordered
    @sucursales_origen = Sucursal.de_recepcion
    @sucursales_entrega = Sucursal.de_retiro
  end
end
