# PR-P.5 · C30-17 / C30-18 · Auditar la pre-factura escaneando
# (`/pre-factura/auditar`).
#
# El paso 2 del recorrido de la Fase 14: con la hoja de preparación lista
# (PR-P.4), el auditor escanea **un** QR de volumen —trae la tanda entera—, y
# después cada etiqueta de Miami: «pertenece» o no. F9 guarda, imprime la
# etiqueta de entrega y deja programado el aviso.
#
# Contesta JSON, como /medicion: el operario mira la pistola, no la pantalla,
# y lo que decide es el sonido. Lo que se escaneó lo lleva la pantalla y lo
# manda en cada pedido; quien vuelve a validarlo todo es
# `GuardarPreFacturaAuditada`.
class AuditarPreFacturaController < ApplicationController
  before_action :autorizar
  before_action :exigir_hoja

  def index; end

  def escanear_volumen
    resultado = auditoria.volumen(params[:codigo].to_s)
    return render json: rechazo_json(resultado) unless resultado.ok?

    render json: { resultado: "ok", mensaje: resultado.mensaje }.merge(tanda_json(resultado))
  end

  def escanear_paquete
    resultado = auditoria.caja(params[:codigo].to_s, escaneadas: Array(params[:escaneadas]))
    render json: { resultado: resultado.tipo.to_s, mensaje: resultado.mensaje, caja_id: resultado.caja&.id }
  end

  def guardar
    pre_factura = GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: sesiones,
                                                escaneadas: Array(params[:escaneadas]), user: Current.user).call
    render json: {
      ok: true, numero: pre_factura.numero, pre_factura_url: pre_factura_path(pre_factura),
      imprimir_url: imprimir_url(pre_factura),
      mensaje: "Pre-factura #{pre_factura.numero} guardada. " +
               (pre_factura.notificado_at ? "El cliente ya quedó avisado." :
                                            "El aviso sale el #{pre_factura.notificar_at.strftime('%d/%m/%Y a las %H:%M')}.")
    }
  rescue GuardarPreFacturaAuditada::NoSePuede => e
    render json: { ok: false, mensaje: e.message }, status: :unprocessable_entity
  end

  private

  # La gente de pre-factura: el mismo permiso que `/pre_facturas` y la hoja.
  def autorizar
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:pre_facturas)
  end

  # Sin hoja lista no hay servicios ni manifiestos contra qué auditar, ni hora
  # para el aviso. Vuelve a la hoja, que dice qué falta.
  def exigir_hoja
    @hoja = HojaDePreparacion.desde_sesion(session[:pf_hoja])
    return if @hoja.lista?

    mensaje = "Primero la hoja de preparación: servicio, manifiesto y fecha de trabajo."
    respond_to do |format|
      format.json { render json: { resultado: "sin_hoja", ok: false, mensaje: mensaje }, status: :unprocessable_entity }
      format.html { redirect_to hoja_de_preparacion_path, alert: mensaje }
    end
  end

  def sesiones = Array(params[:sesiones]).map(&:to_s).compact_blank

  def auditoria = AuditoriaDeTanda.new(hoja: @hoja, sesiones: sesiones)

  def rechazo_json(resultado)
    json = { resultado: resultado.tipo.to_s, mensaje: resultado.mensaje }
    # «Ya está en una pre-factura»: se ofrece abrirla.
    json[:pre_factura_url] = pre_factura_path(resultado.pre_factura) if resultado.pre_factura
    json
  end

  # Lo que pinta la derecha de la pantalla: el cliente en grande, cuántos
  # volúmenes y cajas, cada volumen con sus números, y las líneas tal como van
  # a quedar —de solo lectura: las calcula `ArmarPreFacturaPorVolumen` sin
  # guardar nada—.
  def tanda_json(resultado)
    cajas = resultado.cajas
    bultos = resultado.bultos
    cliente = cajas.first.cliente
    {
      sesion: resultado.sesion,
      cliente: { codigo: cliente&.codigo, nombre: cliente&.nombre_completo },
      tipo_envio: cajas.first.tipo_envio&.nombre,
      pre_alerta: bultos.first.pre_alerta_en_etiqueta,
      aviso_ndem: aviso_ndem(bultos, cajas),
      volumenes: bultos.map { |b| volumen_json(b) },
      cajas: cajas.map { |c| { id: c.id, codigo: helpers.etiqueta_codigo_barras(c) || c.tracking } },
      lineas: vista_previa(cliente, sesiones + [ resultado.sesion ])
    }
  end

  # «Escaneaste 1 de 3: los otros dos ya están», que es lo que Yusef pidió en
  # vez de obligar a escanear los tres (*"solo con uno escanea los otros
  # dos"*).
  def aviso_ndem(bultos, cajas)
    vol = bultos.size == 1 ? "1 volumen" : "#{bultos.size} volúmenes"
    "#{vol} · #{cajas.size} caja#{"s" if cajas.size != 1}"
  end

  def volumen_json(bulto)
    in3 = VolumetricoCalculator.pulgadas_cubicas(bulto.alto, bulto.largo, bulto.ancho) if [ bulto.alto, bulto.largo, bulto.ancho ].all?(&:present?)
    {
      orden: bulto.orden, de_cuantos: bulto.de_cuantos,
      peso: bulto.peso&.to_f, vlbs: bulto.peso_volumetrico&.to_f, peso_cobrar: bulto.peso_cobrar&.to_f,
      pies3: in3 ? VolumetricoCalculator.pies_cubicos_exactos(in3).to_f.round(2) : nil,
      medidas: [ bulto.alto, bulto.largo, bulto.ancho ].all?(&:present?) ? bulto.medidas_texto : nil
    }
  end

  def vista_previa(cliente, todas)
    pf = ArmarPreFacturaPorVolumen.call(cliente: cliente, sesiones: todas)
    pf.send(:calculate_totals)
    {
      items: pf.pre_factura_items.select { |i| i.origen == "volumen" || i.subtotal.to_d.positive? }
               .map { |i| { concepto: i.concepto, subtotal: i.subtotal.to_f } },
      subtotal: pf.subtotal.to_f, impuesto: pf.impuesto.to_f, total: pf.total.to_f, moneda: pf.moneda
    }
  rescue ArmarPreFacturaPorVolumen::NoSePuede => e
    { error: e.message }
  end

  # PR-P.3 · La etiqueta de entrega 4×6. Si su ruta todavía no existe (P.3 en
  # QA), la ficha de la pre-factura.
  def imprimir_url(pre_factura)
    if respond_to?(:etiqueta_entrega_pre_factura_path, true)
      etiqueta_entrega_pre_factura_path(pre_factura, print: true)
    else
      pre_factura_path(pre_factura)
    end
  end
end
