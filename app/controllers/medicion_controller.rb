# C26-02 · Medición: la estación de San Pedro donde cada caja recibida de Miami
# se pesa y se mide **antes** de la pre-factura.
#
# Yusef, en la línea: *"¿cómo vamos a llamar a este módulo? Medición se
# llama."* Lo que necesita: *"el input de tracking, la información de medida y
# peso, y la información de si el cliente está consolidando o no"*.
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

  # Lo que lee la pistola. Seis resultados, y cuatro de ellos son un modal rojo.
  def escanear
    codigo = params[:codigo].to_s.strip
    encontrados = Paquete.por_codigo_de_etiqueta(codigo).includes(:cliente, :tipo_envio).to_a

    if encontrados.empty?
      return render json: { resultado: "no_encontrado", mensaje: "No se encontró ninguna caja con «#{codigo}»." }
    end
    if encontrados.size > 1
      return render json: { resultado: "ambiguo",
                            mensaje: "«#{codigo}» es un envío de #{encontrados.size} cajas: escaneá la etiqueta de la caja, no el tracking." }
    end

    paquete = encontrados.first
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

    grupo = paquete.grupo_de_union
    resultado = grupo&.cerrada? ? "pre_alerta_ya_facturada" : "ok"
    render json: { resultado: resultado, mensaje: mensaje_de(resultado, paquete, grupo),
                   paquete: datos_de(paquete), unir: unir_de(grupo), medicion_previa: previa_de(paquete) }
  end

  def medir
    paquete = Paquete.find(params[:id])
    MedirPaquete.new(paquete, user: Current.user).medir!(params.permit(:peso, :alto, :largo, :ancho))

    grupo = paquete.grupo_de_union
    completo = grupo.present? && !grupo.cerrada? && grupo.completo?
    render json: { ok: true, resultado: completo ? "grupo_completo" : "medido",
                   paquete: datos_de(paquete), unir: unir_de(grupo),
                   mensaje: completo ? "#{grupo.medidos} de #{grupo.total} medidos: el grupo va junto." : mensaje_medido(paquete) }
  rescue MedirPaquete::NoSePuede => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render json: { ok: false, errores: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # C26-03 · Facturar lo que hay: la excepción, con PIN de un jefe.
  def facturar_parcial
    pre_alerta = PreAlerta.find(params[:id])
    AutorizarUnionParcial.new(pre_alerta: pre_alerta,
                              supervisor: User.find_by(id: params[:supervisor_id]),
                              pin: params[:pin], motivo: params[:motivo],
                              solicitado_por: Current.user).call
    grupo = GrupoDeUnion.new(pre_alerta.reload)
    render json: { ok: true, unir: unir_de(grupo),
                   mensaje: "Facturar parcial autorizado por #{pre_alerta.union_parcial_por}: #{grupo.medidos} de #{grupo.total}." }
  rescue AutorizarUnionParcial::NoPermitido, AutorizarUnionParcial::SinMotivo, AutorizarUnionParcial::YaCompleto => e
    render json: { ok: false, errores: [ e.message ] }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    # El PIN lo valida `Autorizacion`, así que su rechazo llega por acá.
    render json: { ok: false, errores: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def authorize_medicion
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:medicion)
  end

  def codigo_de(paquete)
    helpers.etiqueta_codigo_barras(paquete).presence || paquete.tracking
  end

  def datos_de(paquete)
    cliente = paquete.cliente
    { id: paquete.id, codigo: codigo_de(paquete), tracking: paquete.tracking,
      cliente: cliente && "#{cliente.nombre_completo} · #{cliente.codigo}",
      tipo_envio: paquete.tipo_envio&.nombre, descripcion: paquete.descripcion,
      caja: (paquete.cantidad_paquetes.to_i > 1 ? "#{paquete.numero_caja} de #{paquete.cantidad_paquetes}" : nil),
      peso: paquete.peso&.to_f, alto: paquete.alto&.to_f, largo: paquete.largo&.to_f, ancho: paquete.ancho&.to_f,
      peso_volumetrico: paquete.peso_volumetrico&.to_f, peso_cobrar: paquete.peso_cobrar&.to_f,
      medir_url: medir_medicion_path(paquete) }
  end

  def unir_de(grupo)
    return nil if grupo.nil?

    pa = grupo.pre_alerta
    { numero: pa.numero_documento, url: pre_alerta_path(pa),
      total: grupo.total, llegados: grupo.llegados, medidos: grupo.medidos,
      faltantes: grupo.faltantes.map { |f| { tracking: f.tracking, descripcion: f.descripcion, donde: f.donde } },
      completo: grupo.completo?, cerrada: grupo.cerrada?,
      parcial_autorizado: pa.union_parcial_at && { fecha: pa.union_parcial_at.strftime("%d/%m/%Y %H:%M"), por: pa.union_parcial_por },
      facturar_parcial_url: facturar_parcial_medicion_path(pa) }
  end

  def previa_de(paquete)
    return nil if paquete.medido_at.blank?

    { fecha: paquete.medido_at.strftime("%d/%m/%Y %H:%M"), por: paquete.medido_por,
      peso: paquete.peso&.to_f, medidas: "#{paquete.alto&.to_f}x#{paquete.largo&.to_f}x#{paquete.ancho&.to_f}" }
  end

  def mensaje_de(resultado, paquete, grupo)
    if resultado == "pre_alerta_ya_facturada"
      "#{codigo_de(paquete)} es de la pre-alerta #{grupo.pre_alerta.numero_documento}, ya facturada: " \
        "no la unas, hay que partir la pre-alerta. Se mide y se factura aparte."
    elsif grupo
      "#{codigo_de(paquete)} · UNIR con #{grupo.pre_alerta.numero_documento}: #{grupo.medidos} de #{grupo.total} medidos."
    else
      "#{codigo_de(paquete)} · #{paquete.cliente&.nombre_completo}"
    end
  end

  def mensaje_medido(paquete)
    "#{codigo_de(paquete)} medido: #{format('%.2f', paquete.peso.to_f)} lb · " \
      "#{paquete.alto.to_f}x#{paquete.largo.to_f}x#{paquete.ancho.to_f} · VLBS #{format('%.2f', paquete.peso_volumetrico.to_f)}"
  end
end
