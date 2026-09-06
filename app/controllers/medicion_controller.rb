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
    @medidos_hoy = Paquete.where(medido_at: Time.current.all_day)
                          .includes(:cliente, :tipo_envio).order(medido_at: :desc).limit(30)
  end

  # Lo que lee la pistola: el warehouse receipt de la etiqueta de Miami.
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

    # La que toca medir: la primera sin medir del envío, por número de caja.
    paquete = por_caja(encontrados).find { |p| p.medido_at.blank? } || por_caja(encontrados).first
    if paquete.pre_factura_id.present? || paquete.venta_id.present?
      return render json: { resultado: "en_pre_factura", paquete: datos_de(paquete),
                            mensaje: "#{codigo_de(paquete)} ya está en la pre-factura #{paquete.pre_factura&.numero}: " \
                                     "el peso se congeló ahí. No se mide desde acá." }
    end
    unless paquete.estado.in?(Paquete::ESTADOS_FACTURABLES)
      return render json: { resultado: "no_esta_en_honduras", paquete: datos_de(paquete),
                            mensaje: "#{codigo_de(paquete)} está «#{paquete.estado.humanize}»: todavía no se recibió. " \
                                     "Pasala por Recibir Carga." }
    end

    render json: respuesta_de(paquete, paquete.grupo_de_union, resultado_de(paquete))
  end

  def medir
    paquete = Paquete.find(params[:id])
    MedirPaquete.new(paquete, user: Current.user).medir!(params.permit(:peso, :alto, :largo, :ancho))

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
    @paquetes = if params[:hermanas] == "1" && @paquete.dividido?
      [ @paquete, *@paquete.paquetes_hermanos ].select { |p| p.medido_at.present? }.sort_by { |p| p.numero_caja.to_i }
    else
      [ @paquete ].select { |p| p.medido_at.present? }
    end
    raise ActiveRecord::RecordNotFound, "sin medir" if @paquetes.empty?

    render layout: "etiqueta_medicion"
  end

  # Las stickers de un grupo consolidado, juntas: *"que salgan las 3 stickers,
  # una para cada paquete"*. Solo las medidas — una caja sin medir no tiene qué
  # rotular.
  def etiquetas
    grupo = GrupoDeUnion.new(pre_alerta: PreAlerta.find(params[:id]))
    @paquetes = grupo.paquetes_medidos
    raise ActiveRecord::RecordNotFound, "ninguna medida" if @paquetes.empty?

    render :etiqueta, layout: "etiqueta_medicion"
  end

  private

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
      medicion_previa: previa_de(paquete) }
  end

  def por_caja(paquetes) = paquetes.sort_by { |p| [ p.numero_caja.to_i, p.id ] }

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
    { id: p&.id, wr: (codigo_de(p) if p && p.numero_recepcion.present?),
      envio: p&.numero_recepcion, tracking: caja.tracking,
      descripcion: caja.descripcion, caja: (caja_de(p) if p), estado: caja.estado, donde: caja.donde,
      peso: (p&.peso&.to_f if caja.medida?), medidas: (medidas_de(p) if caja.medida?),
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
