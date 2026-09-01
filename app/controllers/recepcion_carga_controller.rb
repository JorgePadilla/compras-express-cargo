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
  before_action :set_manifiesto, only: %i[show escanear finalizar]

  # *"Solo lo que está como enviado."* Un manifiesto que ya se recibió entero no
  # tiene nada que hacer acá.
  def index
    @manifiestos = Manifiesto.activos
                             .where(estado: %w[enviado en_aduana])
                             .includes(:empresa_manifiesto, :consignatario)
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

    if caja.recibida_at.present?
      return render json: { resultado: "ya_recibida", mensaje: "La caja #{caja.letra} ya estaba recibida." }
    end

    servicio.recibir_caja!(caja)
    render json: { resultado: "ok", caja_id: caja.id, letra: caja.letra,
                   mensaje: "Caja #{caja.letra} recibida — #{caja.paquetes.size} paquete(s) a aduana.",
                   faltan: @manifiesto.cajas.where(recibida_at: nil).count }
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

    redirect_to recepcion_carga_index_path,
                notice: "#{@manifiesto.numero} recibido#{" con #{resultado.faltantes.size} caja(s) pendiente(s)" if resultado.faltantes.any?}."
  end

  private

  # `A7-08` · En el interno la pistola lee el **paquete**, no la caja. Acepta el
  # tracking o el número de recepción, que es lo que la etiqueta lleva impreso.
  def escanear_paquete
    codigo = params[:codigo].to_s.strip
    paquete = @manifiesto.paquetes.buscar(codigo).first

    if paquete.nil?
      return render json: { resultado: "no_es_de_aqui",
                            mensaje: "«#{codigo}» no viene en #{@manifiesto.numero}." }
    end

    unless paquete.estado == "enviado_sucursal"
      return render json: { resultado: "ya_recibida",
                            mensaje: "#{paquete.tracking} ya estaba recibido." }
    end

    servicio.recibir_paquete!(paquete)
    render json: { resultado: "ok", paquete_id: paquete.id, tracking: paquete.tracking,
                   mensaje: "#{paquete.tracking} recibido en #{@manifiesto.sucursal_entrega&.nombre}.",
                   faltan: servicio.paquetes_pendientes.count }
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
