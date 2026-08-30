# C21-01 · El escaneo al empacar — el «pip pip pip».
#
# Yusef, mostrando la bodega en vivo por cámara mientras empacaban:
#
#   > "Ahí están empacando, mirá… **y aquí es donde hace falta, es el pip pip
#   >  pip**."
#
# Y la pregunta que abrió el módulo entero:
#
#   > "¿Qué otra forma puedo hacer para empezar a decir que **estos paquetes van
#   >  en esa caja**?"
#
# La `Fase 12` ya lo tenía dibujado desde la Conversación 5, con el detalle que
# importa: *"si el tipo de servicio no concuerda con el de la caja, pita"*, y un
# **botón de omitir** para no trabar la bodega cuando algo no cuadra.
#
# Es también el primer lugar del sistema que escribe el estado `empacado`. Vivía
# en el enum desde siempre y nadie lo asignaba: `EtiquetarController` lo dejó
# reservado con nombre y apellido (*"`empacado` queda reservado para el módulo
# de empaque, que todavía no existe"*).
class EmpaqueController < ApplicationController
  before_action :authorize_manifiestos
  before_action :set_manifiesto
  before_action :set_caja, only: %i[escanear]

  def show
    @cajas = @manifiesto.cajas.ordenadas
    @caja = @cajas.find_by(id: params[:caja_id]) || @cajas.last
    @paquetes = @caja&.paquetes&.includes(:cliente, :tipo_envio)&.order(:created_at) || []
  end

  # Un escaneo. Contesta JSON porque el operario mira la pistola, no la
  # pantalla: lo que decide es el sonido, y la fila se agrega sin recargar.
  def escanear
    codigo = params[:codigo].to_s.strip
    paquete = buscar_paquete(codigo)

    return render json: { resultado: "no_encontrado", mensaje: "No se encontró ningún paquete con «#{codigo}»." } if paquete.nil?

    if ya_esta_en_otra_caja?(paquete)
      return render json: { resultado: "ya_empacado",
                            mensaje: "#{paquete.numero_recepcion_visible} ya está en la caja #{paquete.caja_manifiesto.letra}." }
    end

    unless tipo_permitido?(paquete)
      return render json: {
        resultado: "tipo_distinto",
        mensaje: "#{paquete.numero_recepcion_visible} es #{paquete.tipo_envio&.nombre || "sin tipo"}, " \
                 "y este manifiesto lleva #{@manifiesto.tipos_envio_nuestros}.",
        paquete_id: paquete.id
      }
    end

    empacar!(paquete)
    render json: { resultado: "ok", mensaje: "#{paquete.numero_recepcion_visible} entró a la caja #{@caja.letra}.",
                   fila: fila_de(paquete) }
  end

  # C21-01 · «Omitir»: mete el paquete igual, aunque el tipo no concuerde.
  # La `Fase 12` lo pidió con esas palabras — *"botón de omitir para no trabar
  # la operación cuando algo no cuadra"*. Queda en la bitácora del paquete, que
  # es donde se puede revisar después.
  def omitir
    @caja = @manifiesto.cajas.find(params[:caja_id])
    paquete = Paquete.find(params[:paquete_id])
    empacar!(paquete)
    render json: { resultado: "ok", mensaje: "#{paquete.numero_recepcion_visible} entró igual, omitiendo el aviso.",
                   fila: fila_de(paquete) }
  end

  private

  def authorize_manifiestos
    require_role(:supervisor_miami, :digitador_miami)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:manifiesto_id])
  end

  def set_caja
    @caja = @manifiesto.cajas.find(params[:caja_id])
  end

  # El operario escanea **la etiqueta del paquete**, y ese código de barras es
  # el número de recepción con su sufijo de caja (`etiqueta_codigo_barras`), no
  # el tracking. Se prueban las dos cosas: el número y, si no, la escalera de
  # tracking que ya usa /etiquetar.
  def buscar_paquete(codigo)
    return nil if codigo.blank?

    base = codigo.split("-").first
    Paquete.find_by("UPPER(numero_recepcion) = ?", codigo.upcase) ||
      Paquete.find_by("UPPER(numero_recepcion) = ?", base.to_s.upcase) ||
      Paquete.buscar_escaneado(codigo).first
  end

  def ya_esta_en_otra_caja?(paquete)
    paquete.caja_manifiesto_id.present? && paquete.caja_manifiesto_id != @caja.id
  end

  # *"Si el tipo de servicio no concuerda con el de la caja, pita."* La caja
  # hereda los tipos del manifiesto: son los que el operario eligió al crearlo.
  def tipo_permitido?(paquete)
    @manifiesto.tipo_envio_ids.include?(paquete.tipo_envio_id)
  end

  def empacar!(paquete)
    paquete.update!(caja_manifiesto: @caja, manifiesto: @manifiesto,
                    estado: "empacado")
    @manifiesto.recalculate_totals!
  end

  def fila_de(paquete)
    {
      id: paquete.id,
      recepcion: paquete.numero_recepcion_visible,
      tracking: paquete.tracking,
      cliente: paquete.cliente&.nombre_completo,
      tipo: paquete.tipo_envio&.nombre
    }
  end
end
