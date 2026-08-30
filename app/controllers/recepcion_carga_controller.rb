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
    @cajas = @manifiesto.cajas.ordenadas
  end

  # Se escanean **cajas, no paquetes** (`A7-06`): *"escanearon cada caja, cada
  # etiqueta de manifiesto. No escanean los paquetes, solo escanean las cajas"*.
  def escanear
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
      faltan = resultado.faltantes.map(&:letra).join(", ")
      redirect_to recepcion_carga_path(@manifiesto),
                  alert: "Faltan #{resultado.faltantes.size} de #{@manifiesto.cajas.size}: caja(s) #{faltan}. " \
                         "Podés seguir escaneando, o marcarlo recibido con las pendientes."
      return
    end

    ManifiestoMailer.cajas_faltantes(@manifiesto, resultado.faltantes).deliver_later if resultado.faltantes.any?

    redirect_to recepcion_carga_index_path,
                notice: "#{@manifiesto.numero} recibido#{" con #{resultado.faltantes.size} caja(s) pendiente(s)" if resultado.faltantes.any?}."
  end

  private

  # *"Los de prefactura, ellos son los que se encargan de recibir carga."*
  def authorize_recepcion
    require_role(:supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  def servicio
    @servicio ||= RecibirManifiesto.new(@manifiesto, user: Current.user)
  end
end
