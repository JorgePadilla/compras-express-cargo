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
  include CandadoDelManifiesto

  before_action :authorize_manifiestos
  before_action :set_manifiesto
  before_action :set_caja, only: %i[escanear]
  # C30-06 · Empacar mete paquetes al manifiesto: con el candado puesto, no.
  # Contesta `bloqueado` por JSON, que la pistola hace sonar como error.
  before_action :exigir_modificable, only: %i[alternar escanear omitir]
  # Un paquete con tarea pendiente no sube a un manifiesto que ya salió: la
  # misma guarda que no habría dejado finalizar (`FinalizarManifiesto#enviar`).
  rescue_from Manifiesto::NoEntra do |e|
    render json: { resultado: "trabado", mensaje: e.message }
  end

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
    # PR-C29.20 · «N pqt» de cada caja, en un solo GROUP BY: era un COUNT por
    # caja.
    @paquetes_por_caja = Paquete.where(caja_manifiesto_id: @cajas.map(&:id)).group(:caja_manifiesto_id).count
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
                            mensaje: "#{codigo_de(paquete)} ya está en la caja #{paquete.caja_manifiesto.letra}." }
    end

    unless tipo_permitido?(paquete)
      return render json: {
        resultado: "tipo_distinto",
        mensaje: "#{codigo_de(paquete)} es #{paquete.tipo_envio&.nombre || "sin tipo"}, " \
                 "y este manifiesto lleva #{@manifiesto.tipos_envio_nuestros}.",
        paquete_id: paquete.id
      }
    end

    # C29-07 · La gemela del manifiesto: la casa es del manifiesto, y el
    # manifiesto va a una sucursal. Yusef: *"la idea es que empaquen las cajas
    # de acuerdo a dónde van"*. A diferencia del tipo, **no** se omite: el
    # «Omitir» de la Fase 12 es para el tipo y para nada más.
    unless @manifiesto.acepta_sucursal?(paquete)
      return render json: { resultado: "sucursal_distinta", mensaje: sucursal_distinta(paquete) }
    end

    empacar!(paquete)
    render json: { resultado: "ok", mensaje: "#{codigo_de(paquete)} entró a la caja #{@caja.letra}.",
                   fila: fila_de(paquete) }
  end

  # C21-01 · «Omitir»: mete el paquete igual, aunque el tipo no concuerde.
  # La `Fase 12` lo pidió con esas palabras — *"botón de omitir para no trabar
  # la operación cuando algo no cuadra"*. Queda en la bitácora del paquete, que
  # es donde se puede revisar después.
  def omitir
    @caja = @manifiesto.cajas.find(params[:caja_id])
    paquete = Paquete.find(params[:paquete_id])
    # C29-07 · Omitir salta el tipo, no la sucursal: la pantalla no ofrece el
    # botón para ese caso, y un pedido a mano tampoco lo consigue.
    unless @manifiesto.acepta_sucursal?(paquete)
      return render json: { resultado: "sucursal_distinta", mensaje: sucursal_distinta(paquete) }
    end

    empacar!(paquete)
    render json: { resultado: "ok", mensaje: "#{codigo_de(paquete)} entró igual, omitiendo el aviso.",
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
  #
  # C28-03 · Antes partía el código en el guion y buscaba el número madre: la
  # etiqueta `RMIA…-2` de un split caía en **cualquiera** de sus cajas —la
  # primera que devolviera la base—, y la caja 2 quedaba empacada como si
  # fuera la 1. Ahora va por el mismo resolvedor estricto que el escaneo del
  # manifiesto y la Medición: el sufijo cae en su caja. Si el código trae
  # varias (el tracking de un split), gana una que todavía no esté en caja.
  def buscar_paquete(codigo)
    return nil if codigo.blank?

    candidatos = Paquete.por_etiqueta_o_su_madre(codigo).where.not(estado: Paquete::NO_SON_CAJAS)
    candidatos.where(caja_manifiesto_id: nil).order(:numero_caja, :id).first ||
      candidatos.order(:numero_caja, :id).first
  end

  # El código que dice la etiqueta: el warehouse con su sufijo de caja.
  def codigo_de(paquete)
    helpers.etiqueta_codigo_barras(paquete) || paquete.tracking
  end

  def sucursal_distinta(paquete)
    "#{codigo_de(paquete)} retira en #{paquete.sucursal.nombre}, " \
      "y este manifiesto va a #{@manifiesto.sucursal_entrega.nombre}."
  end

  def ya_esta_en_otra_caja?(paquete)
    paquete.caja_manifiesto_id.present? && paquete.caja_manifiesto_id != @caja.id
  end

  # *"Si el tipo de servicio no concuerda con el de la caja, pita."* La caja
  # hereda los tipos del manifiesto: son los que el operario eligió al crearlo.
  def tipo_permitido?(paquete)
    @manifiesto.acepta_tipo?(paquete)
  end

  # C30-06 · Por `Manifiesto#meter!`, la misma puerta que la ficha: en uno
  # finalizado y reabierto, la caja que se suma al final sale a enviado con
  # todo lo de adentro, como el resto de la carga.
  def empacar!(paquete)
    @manifiesto.meter!(paquete, user: Current.user, caja_manifiesto: @caja, estado: "empacado")
  end

  def fila_de(paquete)
    {
      id: paquete.id,
      # C23-11 · Con varias cajas abiertas la fila tiene que decir **en cuál**
      # entró: si no, la tabla mezcla las tres y no se sabe qué se llenó.
      caja: "#{@caja.letra}#{@caja.numero_bulto}",
      recepcion: codigo_de(paquete),
      tracking: paquete.tracking,
      cliente: paquete.cliente&.nombre_completo,
      tipo: paquete.tipo_envio&.nombre
    }
  end
end
