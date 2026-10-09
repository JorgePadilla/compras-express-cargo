# C21-07 · «La pantallita» y «el aparatito» — recibir la carga en Honduras.
#
#   > **Jorge:** "¿En el sistema qué perfil es el que hace eso?"
#   > **Yusef:** "**Los de prefactura**, ellos son los que se encargan de
#   >  recibir carga."
#
# Cómo es hoy, en sus palabras: *"viene el camión, agarran el montacargas,
# empiezan a descargar, y adentro de la bodega está otro chavo con **esta hoja
# marcando cuál llegó**, y después se van a sistema"*.
#
# Lo que pidió: *"es mejor **una pantallita** que ahí buscara y que **solo le
# aparezca lo que tiene que meter**"* — o sea solo los manifiestos enviados—, y
# *"**el aparatito**: que vengan ellos, llegan a recibir carga, y **escanean la
# caja** y automáticamente el sistema lo [pone]"*. Con pistola, y sobre poco
# volumen: *"como solo son **5 o 10 cajas** lo más que se recibe"*.
class RecepcionCargaController < ApplicationController
  before_action :authorize_recepcion
  before_action :set_manifiesto, only: %i[show escanear finalizar documento]

  # *"Solo lo que está como enviado."* Un manifiesto que ya se recibió entero no
  # tiene nada que hacer acá.
  #
  # C30-09 · `:paquetes` también: la fila dice cuánto va y qué falta
  # (`ProgresoDeRecepcion`), y lo cuenta en memoria — en el interno la unidad
  # es el paquete, y en el oficial los que viajaron sin caja.
  def index
    @manifiestos = RecibirManifiesto.pendientes
                                    .includes(:empresa_manifiesto, :consignatario, :tipo_envios, :tipo_envio_proveedor, :cajas, :paquetes)
                                    .order(fecha_enviado: :desc)
  end

  def show
    # `A7-08` · El interno se cuadra **paquete por paquete**: no lleva casas.
    if @manifiesto.tipo_interno?
      @pendientes = servicio.paquetes_pendientes.includes(:cliente).to_a
      @recibidos = @manifiesto.paquetes.where(estado: "disponible_entrega").includes(:cliente).to_a
      return
    end

    @cajas = @manifiesto.cajas.ordenadas
    # C21-01 · Los que viajaron sin caja, del camino sin escaneo. Sin esto la
    # pantalla decía «0 de 0 recibidas» sobre un manifiesto lleno de paquetes.
    @sin_caja = RecibirManifiesto.new(@manifiesto).paquetes_sin_caja.includes(:cliente).to_a
  end

  # Se escanean **cajas, no paquetes** (`A7-06`): *"escanearon cada caja, cada
  # etiqueta de manifiesto. No escanean los paquetes, solo escanean las cajas"*.
  def escanear
    return escanear_paquete if @manifiesto.tipo_interno?

    codigo = params[:codigo].to_s.strip
    caja = @manifiesto.cajas.find_by("UPPER(codigo) = ?", codigo.upcase)

    return render json: { resultado: "no_es_de_aqui",
                          mensaje: "«#{codigo}» no es una caja de #{@manifiesto.numero}." } if caja.nil?

    render json: recibir_la_caja(caja)
  end

  # C30-09 · La pistola de la lista: escanear **sin elegir el manifiesto**.
  #
  #   > **Yusef:** "A veces vamos a recibir tres manifiestos de un solo y hay
  #   >  que estar seleccionando cada manifiesto, entonces solo crear un
  #   >  search…"
  #   > **Jorge:** "Vamos a implementar un search para que escanea ahí… todos
  #   >  los pendientes."
  #   > **Yusef:** "Si la vuelve a repetir una, solo que avise que ella ya fue
  #   >  recibida."
  #
  # `RecibirManifiesto.ubicar` dice de qué manifiesto es la etiqueta, y de ahí
  # en adelante es **el mismo camino** que la pistola de adentro
  # (`recibir_la_caja` / `recibir_el_paquete`): mismas reglas, mismos efectos
  # —aduana, sucursal, quién recibió, el aviso del interno—. No se cierra solo
  # al completar: «Terminar» sigue siendo un acto aparte, porque cerrar con
  # faltantes manda correo (`A7-06`) y eso no se dispara de rebote.
  def escanear_pendientes
    codigo = params[:codigo].to_s.strip
    ubicacion = RecibirManifiesto.ubicar(codigo)
    @manifiesto = ubicacion.manifiesto

    case ubicacion.motivo
    when :caja then render json: recibir_la_caja(ubicacion.caja)
    when :paquete then render json: recibir_el_paquete(ubicacion.paquete)
    when :paquete_de_oficial
      render json: { resultado: "no_es_de_aqui", manifiesto: progreso,
                     mensaje: "«#{codigo}» es un paquete de #{@manifiesto.numero}. Se escanean las cajas, no los paquetes." }
    when :no_pendiente then render json: caja_fuera_de_recepcion(ubicacion.caja)
    else
      render json: { resultado: "no_es_de_aqui",
                     mensaje: "«#{codigo}» no es de ningún manifiesto pendiente de recibir." }
    end
  end

  # C30-09 · *"Acá afuera sería bueno poder darle también imprimir al
  # manifiesto… lo voy a querer imprimir para darle al oficio."* Es la misma
  # hoja que imprime Miami (`manifiestos/documento`, la de los bultos: *"el
  # manifiesto de la caja… es el mismo"*), pero servida por esta puerta: quien
  # recibe carga no entra a /manifiestos —esa sección es de Miami
  # (`PermisosDelSistema`)— y el botón le habría dado «no tienes permiso».
  def documento
    @cajas = @manifiesto.cajas.includes(:tamano_caja)
    render "manifiestos/documento", layout: "print"
  end

  # Terminar. Si faltan cajas, la primera vez avisa y ofrece las dos salidas de
  # `A7-05`: seguir escaneando, o marcar recibido con las pendientes.
  def finalizar
    resultado = servicio.finalizar!(con_faltantes: params[:con_faltantes].present?)

    if resultado.faltantes.any? && params[:con_faltantes].blank?
      redirect_to recepcion_carga_path(@manifiesto), alert: aviso_de_faltantes(resultado)
      return
    end

    # `A7-06` · El correo es del **internacional**: *"si falta una caja, manda un
    # correo al correo tal"*. En el interno el faltante no se pierde de vista —
    # se queda en `enviado_sucursal`, que es el señalamiento que pidió `A7-09`.
    if resultado.faltantes.any? && @manifiesto.tipo_oficial?
      ManifiestoMailer.cajas_faltantes(@manifiesto, resultado.faltantes).deliver_later
    end

    # `A7-08` · Cerrar avisa a los que **faltaban**: si la ventana ya disparó,
    # son los escaneados después; si no, son todos. La idempotencia está en el
    # paquete (`llegada_notificada_at`), así que un doble submit no repite
    # correos. Ver `NotificarLlegadaASucursal`.
    avisados = @manifiesto.tipo_interno? ? NotificarLlegadaASucursal.new(@manifiesto).call : 0

    redirect_to recepcion_carga_index_path, notice: aviso_de_cierre(resultado, avisados)
  end

  private

  # `A7-08` · En el interno la pistola lee el **paquete**, no la caja. Acepta el
  # tracking o el número de recepción, que es lo que la etiqueta lleva impreso.
  #
  # C30-09 · **Estricto**, como la pistola de la lista. Era `Paquete.buscar`,
  # que hace ILIKE sobre el número del manifiesto, la descripción y el cliente:
  # escanear la hoja del manifiesto —la que el que recibe tiene en la mano—
  # recibía el primer paquete que saliera, sin que nadie lo bajara del camión.
  def escanear_paquete
    codigo = params[:codigo].to_s.strip
    paquete = @manifiesto.paquetes.por_codigo_de_etiqueta(codigo).first

    if paquete.nil?
      return render json: { resultado: "no_es_de_aqui",
                            mensaje: "«#{codigo}» no viene en #{@manifiesto.numero}." }
    end

    render json: recibir_el_paquete(paquete)
  end

  # Una caja de `@manifiesto`, venga de la pistola de adentro o de la de la
  # lista (C30-09). La respuesta lleva el progreso del manifiesto para que la
  # fila de la lista diga «6 de 7 · falta 1» sin recargar.
  def recibir_la_caja(caja)
    if caja.recibida_at.present?
      return { resultado: "ya_recibida", manifiesto: progreso,
               mensaje: "La caja #{caja.letra} de #{@manifiesto.numero} ya estaba recibida." }
    end

    servicio.recibir_caja!(caja)
    { resultado: "ok", caja_id: caja.id, letra: caja.letra, manifiesto: progreso,
      mensaje: "Caja #{caja.letra} de #{@manifiesto.numero} recibida — #{caja.paquetes.size} paquete(s) a aduana.",
      faltan: @manifiesto.cajas.where(recibida_at: nil).count }
  end

  def recibir_el_paquete(paquete)
    unless paquete.estado == "enviado_sucursal"
      return { resultado: "ya_recibida", manifiesto: progreso,
               mensaje: "#{paquete.tracking} ya estaba recibido (#{@manifiesto.numero})." }
    end

    servicio.recibir_paquete!(paquete)
    # `A7-08` · *"Con el manifiesto notifique, pero darle una ventana."* El
    # primer paquete escaneado programa el aviso; los demás no hacen nada.
    NotificarLlegadaASucursal.programar(@manifiesto)
    { resultado: "ok", paquete_id: paquete.id, tracking: paquete.tracking, manifiesto: progreso,
      mensaje: "#{paquete.tracking} recibido en #{@manifiesto.sucursal_entrega&.nombre} (#{@manifiesto.numero}).",
      faltan: servicio.paquetes_pendientes.count }
  end

  # C30-09 · Una caja que existe pero cuyo manifiesto no está para recibir.
  # Si ya se cerró, es la repetida de Yusef: *"que avise que ella ya fue
  # recibida"*. Si se cerró **con ella pendiente**, sus paquetes ya pasaron a
  # aduana igual (`A7-05`): no hay nada que mover, pero conviene saberlo.
  def caja_fuera_de_recepcion(caja)
    if @manifiesto.recibido?
      mensaje = if caja.recibida_at.present?
        "La caja #{caja.letra} de #{@manifiesto.numero} ya fue recibida: el manifiesto ya se cerró."
      else
        "#{@manifiesto.numero} ya se cerró con la caja #{caja.letra} pendiente: sus paquetes ya pasaron a aduana."
      end
      return { resultado: "ya_recibida", mensaje: mensaje }
    end

    mensaje = if @manifiesto.creado?
      "La caja #{caja.letra} es de #{@manifiesto.numero}, que Miami todavía no finalizó."
    else
      "La caja #{caja.letra} es de #{@manifiesto.numero}, que no está pendiente de recibir."
    end
    { resultado: "no_es_de_aqui", mensaje: mensaje }
  end

  # Recontado con una consulta fresca: `recibir_caja!` acaba de tocar la caja
  # por otro objeto, y lo que tenga cargado `@manifiesto` puede estar viejo.
  def progreso
    ProgresoDeRecepcion.new(Manifiesto.includes(:cajas, :paquetes).find(@manifiesto.id)).to_h
  end

  def aviso_de_cierre(resultado, avisados)
    if @manifiesto.tipo_interno?
      pendientes = " · #{resultado.faltantes.size} paquete(s) quedaron señalados como pendientes" if resultado.faltantes.any?
      "#{@manifiesto.numero} recibido. Se avisó a #{avisados} cliente(s)#{pendientes}."
    else
      "#{@manifiesto.numero} recibido#{" con #{resultado.faltantes.size} caja(s) pendiente(s)" if resultado.faltantes.any?}."
    end
  end

  # El faltante se cuenta en su propia unidad: cajas en el oficial, paquetes en
  # el interno. Con el texto de cajas, el interno decía «faltan 3 cajas» sobre un
  # manifiesto que no tiene ninguna.
  def aviso_de_faltantes(resultado)
    if @manifiesto.tipo_interno?
      "Faltan #{resultado.faltantes.size} de #{@manifiesto.paquetes.size} paquete(s). " \
        "Podés seguir escaneando, o cerrarlo y dejarlos señalados como pendientes."
    else
      faltan = resultado.faltantes.map(&:letra).join(", ")
      "Faltan #{resultado.faltantes.size} de #{@manifiesto.cajas.size}: caja(s) #{faltan}. " \
        "Podés seguir escaneando, o marcarlo recibido con las pendientes."
    end
  end

  # *"Los de prefactura, ellos son los que se encargan de recibir carga."*
  def authorize_recepcion
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:recibir_carga)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  def servicio
    @servicio ||= RecibirManifiesto.new(@manifiesto, user: Current.user)
  end
end
