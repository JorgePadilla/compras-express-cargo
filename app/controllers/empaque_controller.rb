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

  # C23-11 · Se empaca en **varias cajas a la vez**.
  #
  # Yusef, describiendo la bodega en temporada:
  #
  #   > "Pero aquí pues **debería de existir la múltiple** […] o sea, poder
  #   >  **seleccionar las tres cajas**."
  #   > "Es que **ellos arman tres cajas y empiezan a meter los paquetes en
  #   >  cualquier caja**."
  #
  # **Un paquete sigue yendo en UNA caja.** Jorge preguntó lo contrario —*"un
  # tracking puede tener tres cajas"*— y Yusef lo corrigió en el acto con ese
  # *"no"*: lo que pasa es que hay tres cajas **llenándose al mismo tiempo**, y
  # el paquete cae en la que tenga lugar. Así que no hay tabla de unión: lo que
  # cambia es la pantalla, no el modelo.
  #
  # El costo que él describió es el de ir a buscar la caja: *"tenés que ir a
  # buscar, o sea, hay que hacerlo bien el proceso"*. Elegir caja era un
  # `link_to` que **recargaba la pantalla**, y con eso el campo de escaneo
  # perdía el foco — con la pistola en la otra mano, eso es un clic por cada
  # cambio de caja.
  def show
    @cajas = @manifiesto.cajas.ordenadas
    @abiertas = cajas_abiertas
    @caja = caja_activa
    # La tabla muestra lo que hay en **todas las abiertas**, no en una: son las
    # que se están llenando a la vez, y verlas juntas es el punto.
    @paquetes = Paquete.where(caja_manifiesto_id: @abiertas.map(&:id))
                       .includes(:cliente, :tipo_envio, :caja_manifiesto)
                       .order(created_at: :desc)
  end

  # C23-11 · Abrir o cerrar una caja del set. *"Y para desempacarlo, lo volvemos
  # a marcar"* — es un interruptor, no dos botones.
  #
  # **Mínimo una**, que Jorge propuso y Yusef ratificó (*"máximo todas"*): sin
  # ninguna abierta el escaneo no tendría a dónde ir, y la pantalla quedaría
  # pidiendo un código que no puede guardar en ningún lado.
  def alternar
    caja = @manifiesto.cajas.find(params[:caja_id])
    abiertas = cajas_abiertas.map(&:id)

    if abiertas.include?(caja.id)
      if abiertas.size == 1
        return render json: { ok: false, mensaje: "Tiene que quedar al menos una caja abierta." }
      end
      abiertas -= [ caja.id ]
    else
      abiertas += [ caja.id ]
    end

    guardar_abiertas(abiertas)
    # Si se cerró la que estaba activa, el escaneo se muda a la primera que
    # quede abierta — nunca a una cerrada.
    activa = abiertas.include?(caja_activa_id) ? caja_activa_id : abiertas.first
    guardar_activa(activa)

    render json: { ok: true, abiertas: abiertas, activa: activa }
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
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:manifiestos)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:manifiesto_id])
  end

  def set_caja
    @caja = @manifiesto.cajas.find(params[:caja_id])
  end

  # ── El set de cajas abiertas ─────────────────────────────────────────────
  #
  # Vive en la **sesión del servidor**, como el tipo de envío de `/etiquetar`:
  # es el estado de un turno de trabajo, no un dato del manifiesto. Recargar no
  # lo pierde, y no le pisa el set a la persona que empaca en la otra mesa.
  #
  # Por defecto están **todas abiertas**, que es «máximo todas» y es lo que
  # deja la pantalla usable sin configurar nada. Cerrar es cómo se achica.
  def cajas_abiertas
    todas = @manifiesto.cajas.ordenadas.to_a
    guardadas = session.dig(:empaque_abiertas, @manifiesto.id.to_s)
    return todas if guardadas.blank?

    # Se filtra contra las que existen: una caja borrada no puede quedar
    # abierta en la sesión de nadie. Y si no queda ninguna, vuelven todas.
    vivas = todas.select { |c| guardadas.include?(c.id) }
    vivas.presence || todas
  end

  def caja_activa
    abiertas = cajas_abiertas
    abiertas.find { |c| c.id == params[:caja_id].to_i } ||
      abiertas.find { |c| c.id == caja_activa_id } ||
      abiertas.first
  end

  def caja_activa_id
    session.dig(:empaque_activa, @manifiesto.id.to_s)
  end

  def guardar_abiertas(ids)
    session[:empaque_abiertas] = (session[:empaque_abiertas] || {}).merge(@manifiesto.id.to_s => ids)
  end

  def guardar_activa(id)
    session[:empaque_activa] = (session[:empaque_activa] || {}).merge(@manifiesto.id.to_s => id)
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
      # C23-11 · Con varias cajas abiertas la fila tiene que decir **en cuál**
      # entró: si no, la tabla mezcla las tres y no se sabe qué se llenó.
      caja: "#{@caja.letra}#{@caja.numero_bulto}",
      recepcion: paquete.numero_recepcion_visible,
      tracking: paquete.tracking,
      cliente: paquete.cliente&.nombre_completo,
      tipo: paquete.tipo_envio&.nombre
    }
  end
end
