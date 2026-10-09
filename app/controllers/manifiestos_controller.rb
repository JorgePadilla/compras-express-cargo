class ManifiestosController < ApplicationController
  # `buscar` (JSON) lo usan operadores que editan paquetes pero no
  # necesariamente tienen rol de Miami — se gatea via authorize_edit
  # del paquete antes de llegar acá.
  before_action :authorize_manifiestos, except: [ :buscar ]
  before_action :set_manifiesto, only: %i[show edit update add_paquete empacar_sin_escanear remove_paquete finalizar documento listado escanear mover_paquete]

  def index
    @manifiestos = Manifiesto.activos.includes(:empresa_manifiesto).order(created_at: :desc)
    @manifiestos = @manifiestos.buscar(params[:q]) if params[:q].present?
    @manifiestos = @manifiestos.by_estado(params[:estado]) if params[:estado].present?
    @manifiestos = @manifiestos.page(params[:page]).per(per_page_sanitized)
  end

  def show
    # C21-04: los tamaños pre-definidos con los que se arma una casa.
    @tamanos = TamanoCaja.activos.ordered
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino, :caja_manifiesto).order(:created_at)
  end

  def new
    @manifiesto = Manifiesto.new
    assigns_del_formulario
  end

  def create
    atributos = manifiesto_params
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

  def edit
    assigns_del_formulario
  end

  def update
    unless @manifiesto.editable_por?(Current.user)
      redirect_to @manifiesto,
                  alert: "#{@manifiesto.numero} está finalizado: solo el supervisor de Miami puede reabrirlo."
      return
    end

    if @manifiesto.update(manifiesto_params)
      redirect_to @manifiesto, notice: "Manifiesto actualizado exitosamente."
    else
      assigns_del_formulario
      render :edit, status: :unprocessable_entity
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

    paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} agregado al manifiesto.")
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
      paquete.update!(manifiesto: @manifiesto, caja_manifiesto: nil,
                      estado: EtiquetarController::ESTADO_AL_ETIQUETAR)
      otro.recalculate_totals!
      @manifiesto.recalculate_totals!
    end
    respond_to_paquete_change("#{paquete.guia} se movió del manifiesto #{otro.numero} a éste.")
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
      redirect_to @manifiesto, alert: "Este manifiesto no admite empacar sin escanear."
      return
    end

    resultado = servicio.call

    if resultado.ninguno?
      # El estado sale del servicio y no escrito a mano: en el oficial es
      # «recibido en Miami» y en el interno «disponible para entrega», y el
      # aviso tiene que nombrar el que de verdad se buscó (`C23-14`).
      redirect_to @manifiesto,
                  alert: "No hay paquetes para agregar. Entran los que están en " \
                         "«#{estado_legible(servicio.estado_buscado)}», del tipo " \
                         "#{@manifiesto.tipos_envio_nuestros}, en " \
                         "#{@manifiesto.sucursal_origen&.nombre || "—"} y todavía sin manifiesto."
      return
    end

    redirect_to @manifiesto,
                notice: "Entraron #{resultado.agregados} paquete(s) sin escanear."
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
    # Con el módulo de empaque todavía sin existir, nadie asigna `empacado`,
    # así que devolver ahí dejaba el paquete en un estado sin dueño: no lo
    # produce ninguna pantalla y no lo consume ningún flujo.
    paquete.update!(manifiesto: nil, estado: EtiquetarController::ESTADO_AL_ETIQUETAR)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} removido del manifiesto.")
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

    # PR-C29.7 · Con `volver=1`, como «Agregar e imprimir»: esto nace de un
    # PATCH y se lleva **esta** pestaña, así que al terminar no hay nada que
    # cerrar —`window.close()` sobre una pestaña que no abrió un script no hace
    # nada— y hay que devolverla a la ficha. Sin esto el operario quedaba
    # mirando las 4×6. Jorge: *"una vez se imprime se regresa a la vista
    # previa"*.
    if params[:imprimir].present? && @manifiesto.cajas.any?
      redirect_to etiquetas_manifiesto_cajas_path(@manifiesto, print: true, volver: 1), notice: aviso
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
  def documento
    @cajas = @manifiesto.cajas.includes(:tamano_caja)
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

  def respond_to_paquete_change(message, tipo: :notice)
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino, :caja_manifiesto).order(:created_at)
    @manifiesto.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("manifiesto-paquetes", partial: "manifiestos/paquetes_table", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          # C21-06 · Los botones de cierre **también**. Se actualizaba solo la
          # tabla, y como «Solo Finalizar» solo se dibuja con `paquetes.any?`,
          # al agregar el primer paquete la tabla se llenaba y el botón no
          # aparecía: la única forma de finalizar era recargar la pantalla. Y al
          # quitar el último pasa al revés — el botón quedaba ofreciendo
          # finalizar un manifiesto vacío.
          # Van los dos: el bloque está arriba y abajo porque con la tabla
          # llena el de arriba queda a una pantalla de distancia. Refrescar uno
          # solo dejaría al otro mintiendo.
          turbo_stream.update("manifiesto-acciones-arriba", partial: "manifiestos/acciones", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.update("manifiesto-acciones-abajo", partial: "manifiestos/acciones", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { tipo => message })
        ]
      end
      format.html { redirect_to @manifiesto, tipo => message }
    end
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
      # `A7-07` · Oficial o interno. El formulario solo lo deja elegir al crear;
      # en uno guardado va como hidden, porque el número ya salió y la carga ya
      # se movió con las reglas de su tipo.
      :tipo,
      tipo_envio_ids: []
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
