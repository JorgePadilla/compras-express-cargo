# C26-02 · Medición: la estación de San Pedro donde cada caja recibida de Miami
# se pesa y se mide **antes** de la pre-factura.
#
# Yusef, en la línea: *"¿cómo vamos a llamar a este módulo? Medición se
# llama."* Jorge, corrigiendo la primera versión: *"se escanea el warehouse
# receipt y me tiene que avisar **cómo está en la pre-alerta y cómo ingresó en
# Miami**… los cuadritos: lo que está y lo que falta"*.
#
# Por eso el escaneo no responde una caja: responde **el grupo**. Los dos lados
# del dato —lo que el cliente declaró y lo que Miami ingresó— van separados a
# propósito: pueden no coincidir, y esa diferencia es información (el tipo de
# envío cambia en Miami bastante seguido, por eso existe
# `PreAlerta#sincronizar_tipo_envio_desde_paquetes!`).
#
# Por qué antes de la pre-factura: la pre-factura **copia** `peso_cobrar` al
# crearse y no lo vuelve a leer. Una caja que ya está en una pre-factura no se
# mide desde acá, y se dice con un modal.
#
# Todo por JSON, sin recargar: son *"mil, dos mil paquetes"* por manifiesto y
# el operario tiene la pistola en una mano.
class MedicionController < ApplicationController
  before_action :authorize_medicion

  def index
    @puede_descartar = admin?
  end

  # C26-17 · El panel de la derecha: lo que **falta** del manifiesto que se está
  # procesando. Jorge: *"¿cómo ayuda eso de «medidos hoy»? Sería bueno que
  # aparezcan los que faltan de ese manifiesto, así como match con lo que se
  # mandó desde Miami"*.
  #
  # Se pide al cargar la pantalla —con el último manifiesto que todavía tiene
  # algo que medir— y después de cada escaneo, con el de la caja en la mano.
  def panel
    render json: { manifiesto: manifiesto_json(manifiesto_por_defecto) }
  end

  # C26-17 · Sacar una caja de la lista: perdida, o ya entregada. Solo admin.
  def descartar
    paquete = Paquete.find(params[:id])
    DescartarDeMedicion.new(paquete: paquete, user: Current.user)
                       .descartar!(motivo: params[:motivo], nota: params[:nota])

    render json: { ok: true, manifiesto: manifiesto_json(paquete.manifiesto),
                   mensaje: "#{codigo_de(paquete)} salió de la lista: " \
                            "#{DescartarDeMedicion::MOTIVOS[paquete.medicion_descartada_motivo].downcase}." }
  rescue DescartarDeMedicion::NoPermitido => e
    render json: { ok: false, errores: [ e.message ] }, status: :forbidden
  rescue DescartarDeMedicion::SinMotivo => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  end

  def restaurar
    paquete = Paquete.find(params[:id])
    DescartarDeMedicion.new(paquete: paquete, user: Current.user).restaurar!

    render json: { ok: true, manifiesto: manifiesto_json(paquete.manifiesto),
                   mensaje: "#{codigo_de(paquete)} vuelve a la lista." }
  rescue DescartarDeMedicion::NoPermitido => e
    render json: { ok: false, errores: [ e.message ] }, status: :forbidden
  end

  # C27-02 · Lo que lee la pistola. Con el bulto ya no pregunta «traeme esta
  # caja para medirla» sino **«¿esta caja puede entrar a la mesa?»**.
  #
  # Yusef, el 2026-09-07, cuando Jorge le preguntó cómo se unen las cajas de una
  # medición: *"No, no, porque se van a equivocar. Eso es un error ya. No van a
  # leer."* — *"¿Entonces cómo los unís?"* — **"Escaneando. Escaneando cada
  # uno."** Por eso no hay checkboxes ni lista de dónde elegir: el bulto se arma
  # pip a pip, y cada pip lo valida `PuedenIrJuntas`.
  #
  # `en_tanda` son las cajas que el operario ya tiene, **de toda la tanda** y no
  # solo de la mesa: «NO Mezclar» es de la sesión entera —dos volúmenes de la
  # misma mesa son del mismo cliente y del mismo servicio, y eso lo vuelve a
  # verificar `MedirBulto` al guardar—. Si mirara solo la mesa, el error del
  # segundo volumen saldría recién en F10, con el primero ya medido.
  def escanear
    codigo = params[:codigo].to_s.strip
    encontrados = Paquete.por_codigo_de_etiqueta(codigo).includes(:cliente, :tipo_envio, :user).to_a

    if encontrados.empty?
      return render json: { resultado: "no_encontrado", mensaje: "No se encontró ninguna caja con «#{codigo}»." }
    end
    # C26-02 · **Varias cajas con el mismo warehouse receipt no son una
    # ambigüedad: son un envío partido**, y es justo lo que Jorge quiere ver al
    # escanear —*"me deberían aparecer los datos de los otros paquetes"*—. La
    # guarda de abajo se escribió pensando en un tracking repetido entre envíos
    # distintos, que es la ambigüedad de verdad y sigue saliendo en rojo.
    envio = encontrados.map(&:numero_recepcion).uniq
    if encontrados.size > 1 && (envio.size > 1 || envio.first.blank?)
      return render json: { resultado: "ambiguo",
                            mensaje: "«#{codigo}» aparece en #{envio.compact.size} envíos distintos " \
                                     "(#{envio.compact.take(2).join(", ")}…): escaneá el warehouse receipt de la caja que tenés en la mano." }
    end

    # C27-02 · La que toca: la primera del envío que **no esté ya en la tanda**.
    # Las cajas de un split llevan el mismo código impreso, así que escanear el
    # mismo warehouse tres veces pone las tres en la mesa —una por pip, que es
    # justo el gesto que Yusef describió.
    candidatas = por_caja(encontrados)
    paquete = candidatas.find { |p| !en_tanda.include?(p.id) && p.medido_at.blank? } ||
              candidatas.find { |p| !en_tanda.include?(p.id) } ||
              candidatas.first
    if paquete.pre_factura_id.present? || paquete.venta_id.present?
      return render json: { resultado: "en_pre_factura", paquete: datos_de(paquete),
                            mensaje: "#{codigo_de(paquete)} ya está en la pre-factura #{paquete.pre_factura&.numero}: " \
                                     "el peso se congeló ahí. No se mide desde acá." }
    end
    # C27-09 · Una caja que ya tiene bulto no se vuelve a medir: se reimprime.
    # Yusef: *"él va a poder reimprimir la etiqueta, porque digamos que si se le
    # cae… ¿cómo la buscaría? **Tendría que volver a escanear el warehouse**"*.
    if paquete.bulto_id.present?
      return render json: { resultado: "ya_tiene_bulto", paquete: datos_de(paquete),
                            bulto: bulto_json(paquete.bulto),
                            mensaje: mensaje_ya_medido(paquete.bulto) }
    end
    # C27-14 · El estado se **avisa**, no bloquea. Yusef, mirando el bloqueo en
    # vivo: *"este tiene un bloqueo ahorita que me tiene loco: si no ha pasado
    # el proceso desde Miami para acá, no lo puede hacer… a más de alguno se le
    # va a escapar. **Hay que poner una opción ahí.**"* El modal rojo sigue
    # saliendo —esa información vale, la caja de verdad no pasó por aduana—,
    # pero con la salida puesta, y quien la usa deja su nombre.
    if !paquete.estado.in?(Paquete::ESTADOS_FACTURABLES) && !saltar_manifiesto?
      return render json: { resultado: "no_esta_en_honduras", paquete: datos_de(paquete),
                            puede_saltar: true, estado: paquete.estado.humanize,
                            mensaje: "#{codigo_de(paquete)} está «#{paquete.estado.humanize}»: no pasó por Recibir Carga. " \
                                     "Se puede medir igual —queda anotado con tu nombre— o pasala primero por su manifiesto." }
    end

    # «NO Mezclar»: la pizarra del 2026-09-07. La caja rechazada **no entra a
    # la mesa** — la respuesta no trae `mesa: true` y el JS no la agrega.
    if (problema = PuedenIrJuntas.new(ya_escaneadas, paquete).problema)
      return render json: { resultado: "no_mezclar", motivo: problema.motivo, mensaje: problema.mensaje,
                            paquete: datos_de(paquete), choque: choque_json(problema) }
    end

    render json: respuesta_de(paquete, paquete.grupo_de_union, resultado_de(paquete))
             .merge(mesa: true, salto_manifiesto: !paquete.estado.in?(Paquete::ESTADOS_FACTURABLES))
  end

  # C27-01 · Guardar la tanda entera: las mediciones que el operario armó en la
  # mesa, con sus números, y las etiquetas que salen —**una por medición**.
  #
  # Yusef: *"mide y pesa este, le da agregar; mide y pesa este por separado
  # porque no cuadra… y ahí le dice imprimir, y como son dos mediciones,
  # imprime dos"*. Todo entra junto porque el «1 de 2» del QR necesita saber
  # cuántas son antes de imprimir la primera.
  def guardar
    bultos = MedirBulto.new(user: Current.user, saltar_manifiesto: params[:saltar_manifiesto])
                       .guardar!(mediciones_permitidas)
    cajas = bultos.sum { |b| b.paquetes.size }

    primera = bultos.first.paquetes.first
    render json: { ok: true, cantidad: bultos.size,
                   mensaje: mensaje_guardado(bultos, cajas),
                   imprimir_url: etiquetas_sesion_medicion_path(bultos.first.sesion, print: "true"),
                   bultos: bultos.map { |b| bulto_json(b) },
                   manifiesto: manifiesto_json(primera&.manifiesto),
                   # El grupo **después** de sellar: la pantalla lo usa para
                   # ofrecer «Facturar lo que hay» en el banner, solo si el
                   # consolidado quedó incompleto. Antes ese botón vivía en rojo
                   # permanente al lado de la grilla, con la mesa completa.
                   grupo: grupo_json(primera&.grupo_de_union) }
  rescue MedirBulto::NoSePuede => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, errores: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def medir
    paquete = Paquete.find(params[:id])
    MedirPaquete.new(paquete, user: Current.user, saltar_manifiesto: saltar_manifiesto?)
                .medir!(params.permit(:peso, :alto, :largo, :ancho))

    grupo = paquete.grupo_de_union
    completo = grupo.present? && !grupo.cerrada? && grupo.completo?
    render json: respuesta_de(paquete, grupo, completo ? "grupo_completo" : "medido").merge(
      ok: true,
      mensaje: completo ? "#{grupo.medidas} de #{grupo.total} medidas: el grupo va junto." : mensaje_medido(paquete),
      # Las stickers salen **juntas** al completar el grupo; una caja suelta
      # imprime la suya al guardarla.
      imprimir_url: completo ? etiquetas_url_de(grupo) : (grupo ? nil : etiqueta_medicion_path(paquete, print: "true"))
    )
  rescue MedirPaquete::NoSePuede => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, errores: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # C26-03 · «Facturar lo que hay»: el grupo sigue incompleto y hay que pasar.
  # Sin PIN — Jorge: *"se pone una alerta y se pasa"*. Queda sellado en la
  # pre-alerta, con qué faltaba, en su historial.
  def facturar_parcial
    pre_alerta = PreAlerta.find(params[:id])
    grupo = PasarGrupoIncompleto.new(pre_alerta: pre_alerta, user: Current.user).call

    render json: { ok: true, grupo: grupo_json(grupo),
                   imprimir_url: (etiquetas_url_de(grupo) if grupo.paquetes_medidos.any?),
                   mensaje: "Se pasa sin el grupo completo (#{pre_alerta.union_parcial_por}): " \
                            "#{grupo.medidas} de #{grupo.total} medidas." }
  rescue PasarGrupoIncompleto::YaCompleto => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  end

  # C26-04 · La etiqueta de una caja. Con `hermanas=1`, las de todo el split en
  # un solo documento.
  def etiqueta
    @paquete = Paquete.find(params[:id])
    # C27-06 · Si la caja se midió en un bulto, su etiqueta **es la del bulto**:
    # una por medición, no una por caja.
    if @paquete.bulto_id.present?
      @bultos = [ @paquete.bulto ]
      return render :etiqueta_bulto, layout: "etiqueta_medicion"
    end
    # C26-04 · Las cajas del envío salen por **warehouse receipt** y no por
    # `dividido?`: ese campo puede venir vacío, y entonces salía **una sola**
    # etiqueta —el bug que Jorge vio en «Reimprimir el grupo»—. Es el mismo
    # `dividido?` que ya se había sacado de `GrupoDeUnion` y que quedó vivo acá.
    @paquetes = if params[:hermanas] == "1"
      @paquete.cajas_del_mismo_envio.where.not(medido_at: nil).to_a.presence ||
        [ @paquete ].select { |p| p.medido_at.present? }
    else
      [ @paquete ].select { |p| p.medido_at.present? }
    end
    raise ActiveRecord::RecordNotFound, "sin medir" if @paquetes.empty?

    render layout: "etiqueta_medicion"
  end

  # Las stickers de un grupo consolidado, juntas: *"que salgan las 3 stickers,
  # una para cada paquete"*. Solo las medidas — una caja sin medir no tiene qué
  # rotular.
  #
  # C27-06 · Y si las cajas ya están en bultos, sale **una etiqueta por bulto**
  # y no una por caja: es la regla que Yusef dijo tres veces. Un grupo medido
  # con el camino viejo —`MedirPaquete`, sin bulto— sigue saliendo caja por
  # caja, que es lo que esas cajas tienen.
  def etiquetas
    grupo = GrupoDeUnion.new(pre_alerta: PreAlerta.find(params[:id]))
    medidos = grupo.paquetes_medidos
    raise ActiveRecord::RecordNotFound, "ninguna medida" if medidos.empty?

    @bultos = medidos.filter_map(&:bulto).uniq.sort_by(&:orden)
    @paquetes = medidos.reject(&:bulto_id)
    return render :etiqueta_bulto, layout: "etiqueta_medicion" if @paquetes.empty?

    render :etiqueta, layout: "etiqueta_medicion"
  end

  # C27-06 · Las etiquetas de una tanda: una por medición, en el orden en que el
  # operario las fue agregando.
  def etiquetas_sesion
    @bultos = Bulto.de_la_sesion(params[:sesion]).includes(:paquetes).to_a
    raise ActiveRecord::RecordNotFound, "sesión vacía" if @bultos.empty?

    render :etiqueta_bulto, layout: "etiqueta_medicion"
  end

  # C27-09 · Reimprimir una sola medición, la que ampara la caja que se escaneó.
  def etiqueta_bulto
    @bultos = [ Bulto.find(params[:id]) ]

    render :etiqueta_bulto, layout: "etiqueta_medicion"
  end

  private

  # Las cajas que el operario ya tiene en la tanda —mesa **y** volúmenes ya
  # agregados—, en el orden en que las escaneó: `PuedenIrJuntas` compara todo
  # contra la primera.
  def en_tanda
    @en_tanda ||= Array(params[:en_tanda]).map(&:to_i).reject(&:zero?).uniq
  end

  # C27-14 · La pantalla lo manda **por caja**, después de que alguien apretó
  # «Medirlo igual» en el modal rojo. No es un modo que quede prendido.
  def saltar_manifiesto? = params[:saltar_manifiesto].to_s == "true"

  # Lista blanca, aunque `MedirBulto` ya lea campo por campo —`paquete_ids` y
  # los cuatro de `MedirPaquete::CAMPOS`— y nunca haga un assign masivo. Se
  # escribe igual para que el filtro se **vea** en la puerta y no dependa de que
  # el modelo siga leyendo así: es lo que pidió la revisión del PR-445.
  def mediciones_permitidas
    Array(params[:mediciones]).map do |medicion|
      medicion.permit(:peso, :alto, :largo, :ancho, paquete_ids: [])
    end
  end

  def ya_escaneadas
    return [] if en_tanda.empty?

    por_id = Paquete.where(id: en_tanda).includes(:cliente, :tipo_envio).index_by(&:id)
    en_tanda.filter_map { |id| por_id[id] }
  end

  # Lo que el modal rojo del consolidado tiene que decir: con qué pre-alerta
  # choca la caja, y con qué pre-factura si ya la tiene. Yusef: *"un modal que
  # le diga: hey, no, ese está consolidando con tal pre-alerta, con tal número.
  # Ese va amarrado con otra."*
  def choque_json(problema)
    pa = problema.pre_alerta
    return nil if pa.nil?

    { numero: pa.numero_documento, titulo: pa.titulo, url: pre_alerta_path(pa),
      pre_factura: pre_factura_de(pa)&.numero }
  end

  def pre_factura_de(pre_alerta)
    Paquete.joins(:pre_alerta_paquetes)
           .where(pre_alerta_paquetes: { pre_alerta_id: pre_alerta.id })
           .where.not(pre_factura_id: nil).includes(:pre_factura).first&.pre_factura
  end

  def bulto_json(bulto)
    return nil if bulto.nil?

    { id: bulto.id, sesion: bulto.sesion, de_cuantos_texto: bulto.de_cuantos_texto,
      cajas: bulto.paquetes.size, peso: bulto.peso&.to_f, medidas: bulto.medidas_texto,
      peso_volumetrico: bulto.peso_volumetrico&.to_f, peso_cobrar: bulto.peso_cobrar&.to_f,
      fecha: bulto.medido_at.strftime("%d/%m/%Y %H:%M"), por: bulto.medido_por,
      etiqueta_url: etiqueta_bulto_medicion_path(bulto, print: "true") }
  end

  def mensaje_ya_medido(bulto)
    detalle = [ bulto.de_cuantos_texto, "#{bulto.paquetes.size} caja#{"s" if bulto.paquetes.size != 1}" ].compact
    "Esta caja ya está medida: #{format('%.2f', bulto.peso.to_f)} lb · #{bulto.medidas_texto} " \
      "(#{detalle.join(' · ')}), por #{bulto.medido_por} el #{bulto.medido_at.strftime('%d/%m/%Y %H:%M')}. " \
      "Podés reimprimir su etiqueta."
  end

  def mensaje_guardado(bultos, cajas)
    if bultos.size == 1
      "Medición guardada: #{cajas} caja#{"s" if cajas != 1} en un solo bulto, una etiqueta."
    else
      "#{bultos.size} volúmenes guardados con #{cajas} cajas: #{bultos.size} etiquetas."
    end
  end

  def authorize_medicion
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:medicion)
  end

  def resultado_de(paquete)
    grupo = paquete.grupo_de_union
    grupo&.cerrada? ? "pre_alerta_ya_facturada" : "ok"
  end

  # La respuesta completa del escaneo: la caja para el formulario, los dos
  # lados del dato, y el grupo para la grilla.
  def respuesta_de(paquete, grupo, resultado)
    { resultado: resultado, mensaje: mensaje_de(resultado, paquete, grupo),
      paquete: datos_de(paquete), miami: miami_de(paquete),
      pre_alerta: pre_alerta_json(grupo), grupo: grupo_json(grupo, paquete.id),
      manifiesto: manifiesto_json(paquete.manifiesto, paquete.id),
      medicion_previa: previa_de(paquete) }
  end

  def por_caja(paquetes) = paquetes.sort_by { |p| [ p.numero_caja.to_i, p.id ] }

  # El manifiesto con el que arranca la pantalla: el más reciente que todavía
  # tiene algo que medir.
  def manifiesto_por_defecto
    Manifiesto.activos
              .joins(:paquetes)
              .where(paquetes: { estado: Paquete::ESTADOS_FACTURABLES, medido_at: nil, medicion_descartada_at: nil })
              .order(fecha_aduana: :desc, id: :desc).first
  end

  # C26-17 · El manifiesto y lo que le falta. El encabezado es el «match con lo
  # que se mandó desde Miami»; la lista, lo que el operario todavía tiene que
  # buscar o medir.
  def manifiesto_json(manifiesto, midiendo_id = nil)
    return nil if manifiesto.nil?

    resumen = manifiesto.resumen_de_medicion
    resumen.merge(
      numero: manifiesto.numero,
      guia: manifiesto.numeros_de_guia.join(" · ").presence,
      enviado: manifiesto.fecha_enviado&.strftime("%d/%m/%Y"),
      recibido: manifiesto.fecha_aduana&.strftime("%d/%m/%Y"),
      puede_descartar: admin?,
      pendientes: pendientes_de(manifiesto, midiendo_id)
    )
  end

  # Primero lo que está acá esperando que lo midan; al final, lo que no llegó
  # —que es lo que hay que ir a buscar, no lo que hay que medir.
  def pendientes_de(manifiesto, midiendo_id)
    paquetes = manifiesto.paquetes.pendientes_de_medicion.includes(:cliente).to_a
    uniones = uniones_de(paquetes)

    paquetes.sort_by { |p| [ p.esperando_medicion? ? 0 : 1, p.numero_recepcion.to_s, p.numero_caja.to_i ] }
            .map do |p|
      { id: p.id, wr: codigo_de(p), caja: caja_de(p), cliente: p.cliente&.nombre_completo,
        donde: p.esperando_medicion? ? "acá, sin medir" : "no llegó a Honduras",
        aqui: p.esperando_medicion?, midiendo: p.id == midiendo_id,
        unir: uniones[p.id], descartar_url: descartar_medicion_path(p) }
    end
  end

  # C26-17 · Cuáles de los pendientes vienen **consolidados**, y con cuál
  # pre-alerta. Jorge: *"¿cómo sé si los warehouse receipts vienen consolidados
  # en una pre-alerta?"* — antes había que escanear uno para enterarse; acá se
  # ve la lista entera de un vistazo.
  #
  # Una sola consulta para todos: preguntarle a `GrupoDeUnion` paquete por
  # paquete serían 40 consultas en un manifiesto normal.
  def uniones_de(paquetes)
    return {} if paquetes.empty?

    PreAlertaPaquete.joins(:pre_alerta)
                    .merge(PreAlerta.activas.where(consolidado: true, finalizado: false))
                    .where("pre_alerta_paquetes.paquete_id IN (:ids) OR UPPER(pre_alerta_paquetes.tracking) IN (:trk)",
                           ids: paquetes.map(&:id), trk: paquetes.map { |p| p.tracking.to_s.upcase })
                    .includes(:pre_alerta)
                    .each_with_object({}) do |renglon, acc|
      numero = renglon.pre_alerta.numero_documento
      paquetes.each do |p|
        acc[p.id] ||= numero if renglon.paquete_id == p.id || renglon.tracking.to_s.casecmp?(p.tracking.to_s)
      end
    end
  end

  def codigo_de(paquete)
    helpers.etiqueta_codigo_barras(paquete).presence || paquete.tracking
  end

  def caja_de(paquete)
    return nil unless paquete.cantidad_paquetes.to_i > 1

    "#{paquete.numero_caja} de #{paquete.cantidad_paquetes}"
  end

  def datos_de(paquete)
    cliente = paquete.cliente
    { id: paquete.id, codigo: codigo_de(paquete), wr: paquete.numero_recepcion, tracking: paquete.tracking,
      cliente: cliente && "#{cliente.nombre_completo} · #{cliente.codigo}",
      tipo_envio: paquete.tipo_envio&.nombre, descripcion: paquete.descripcion,
      caja: caja_de(paquete),
      peso: paquete.peso&.to_f, alto: paquete.alto&.to_f, largo: paquete.largo&.to_f, ancho: paquete.ancho&.to_f,
      peso_volumetrico: paquete.peso_volumetrico&.to_f, peso_cobrar: paquete.peso_cobrar&.to_f,
      medir_url: medir_medicion_path(paquete),
      etiqueta_url: (etiqueta_medicion_path(paquete, print: "true") if paquete.medido_at.present?) }
  end

  # Cómo ingresó Miami esta caja. `numero_recepcion` en blanco significa que
  # Miami todavía no la tiene: es un paquete «esperado» de la pre-alerta.
  def miami_de(paquete)
    return nil if paquete.numero_recepcion.blank?

    { wr: codigo_de(paquete), recibido: paquete.fecha_recibido_miami&.strftime("%d/%m/%Y"),
      por: paquete.user&.iniciales_display, descripcion: paquete.descripcion,
      tipo_envio: paquete.tipo_envio&.nombre, caja: caja_de(paquete),
      retenido: paquete.retener_miami? }
  end

  # Lo que el cliente declaró. Puede no coincidir con lo de arriba.
  def pre_alerta_json(grupo)
    pa = grupo&.pre_alerta
    return nil if pa.nil?

    { numero: pa.numero_documento, url: pre_alerta_path(pa), titulo: pa.titulo, proveedor: pa.proveedor,
      consolidado: pa.consolidado?, con_reempaque: pa.con_reempaque?, notas: pa.notas_grupo,
      tipo_envio: pa.tipo_envio&.nombre, trackings: pa.pre_alerta_paquetes.size }
  end

  # El grupo, para la grilla de cuadritos.
  def grupo_json(grupo, seleccionada_id = nil)
    return nil if grupo.nil?

    pa = grupo.pre_alerta
    { consolidada: grupo.consolidada?, numero: pa&.numero_documento,
      total: grupo.total, medidas: grupo.medidas, llegadas: grupo.llegadas,
      completo: grupo.completo?, cerrada: grupo.cerrada?,
      parcial_autorizado: (pa&.union_parcial_at && { fecha: pa.union_parcial_at.strftime("%d/%m/%Y %H:%M"),
                                                     por: pa.union_parcial_por }),
      facturar_parcial_url: (facturar_parcial_medicion_path(pa) if pa),
      etiquetas_url: etiquetas_url_de(grupo),
      cajas: grupo.cajas.map { |c| caja_json(c, seleccionada_id) } }
  end

  def caja_json(caja, seleccionada_id)
    p = caja.paquete
    # C27-01 · Con bulto, los números que valen son los del bulto: a la caja
    # `MedirBulto` **no le pisa** su peso ni sus medidas —ésos son el dato de
    # Miami— porque el que cobra es el bulto.
    numeros = p&.bulto || p
    { id: p&.id, wr: (codigo_de(p) if p && p.numero_recepcion.present?),
      envio: p&.numero_recepcion, tracking: caja.tracking,
      descripcion: caja.descripcion, caja: (caja_de(p) if p), estado: caja.estado, donde: caja.donde,
      peso: (numeros&.peso&.to_f if caja.medida?), medidas: (medidas_de(numeros) if caja.medida?),
      por: p&.medido_por, seleccionada: p.present? && p.id == seleccionada_id,
      medible: caja.aqui? || caja.medida? }
  end

  def medidas_de(paquete)
    "#{paquete.alto&.to_f}x#{paquete.largo&.to_f}x#{paquete.ancho&.to_f}"
  end

  # Dónde están las stickers del grupo: la ruta del grupo si hay pre-alerta, y
  # si es un split suelto, la de la caja con sus hermanas.
  def etiquetas_url_de(grupo)
    return nil if grupo.nil? || grupo.paquetes_medidos.empty?
    return etiquetas_grupo_medicion_path(grupo.pre_alerta, print: "true") if grupo.pre_alerta

    etiqueta_medicion_path(grupo.paquetes_medidos.first, hermanas: "1", print: "true")
  end

  def previa_de(paquete)
    return nil if paquete.medido_at.blank?

    { fecha: paquete.medido_at.strftime("%d/%m/%Y %H:%M"), por: paquete.medido_por,
      peso: paquete.peso&.to_f, medidas: medidas_de(paquete) }
  end

  def mensaje_de(resultado, paquete, grupo)
    if resultado == "pre_alerta_ya_facturada"
      "#{codigo_de(paquete)} es de la pre-alerta #{grupo.pre_alerta.numero_documento}, ya facturada: " \
        "no la unas, hay que partir la pre-alerta. Se mide y se factura aparte."
    elsif grupo&.consolidada?
      "#{codigo_de(paquete)} · UNIR con #{grupo.pre_alerta.numero_documento}: #{grupo.medidas} de #{grupo.total} medidas."
    elsif grupo && grupo.pre_alerta.nil?
      "#{codigo_de(paquete)} · #{grupo.total} cajas con este warehouse receipt: " \
        "#{grupo.medidas} medidas, vas por la #{paquete.numero_caja || 1} de #{grupo.total}."
    elsif grupo
      "#{codigo_de(paquete)} · viene partido en #{grupo.total} cajas: #{grupo.medidas} medidas."
    else
      "#{codigo_de(paquete)} · #{paquete.cliente&.nombre_completo}"
    end
  end

  def mensaje_medido(paquete)
    "#{codigo_de(paquete)} medido: #{format('%.2f', paquete.peso.to_f)} lb · " \
      "#{paquete.alto.to_f}x#{paquete.largo.to_f}x#{paquete.ancho.to_f} · VLBS #{format('%.2f', paquete.peso_volumetrico.to_f)}"
  end
end
