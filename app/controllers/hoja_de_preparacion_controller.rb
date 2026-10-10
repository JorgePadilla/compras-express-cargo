# PR-P.4 · C30-15 · La hoja de preparación de la pre-factura (`/pre-factura/hoja`).
#
# Una pantalla, tres bloques, como el diagrama de Yusef (foto 3): el modo
# —servicios a trabajar **o** editar pre-facturas—, los manifiestos, y la fecha
# de trabajo. Lo elegido vive en `session[:pf_hoja]`, igual que la sesión de
# `/etiquetar`; `destroy` la cierra. La regla está en `HojaDePreparacion`.
class HojaDePreparacionController < ApplicationController
  before_action :autorizar
  before_action :cargar_hoja

  def show
    @tipos = TipoEnvio.activos.order(:nombre)
    @manifiestos = @hoja.manifiestos_ofrecidos.includes(:tipo_envios).to_a
    ids = @manifiestos.map(&:id)

    # Lo que dice cada tarjeta, en tres consultas agrupadas y no tres por
    # tarjeta (la lección de PR-C29.20).
    del_servicio = Paquete.where(manifiesto_id: ids)
    del_servicio = del_servicio.where(tipo_envio_id: @hoja.tipo_envio_ids) if @hoja.nuevas?
    @total_por_manifiesto = del_servicio.group(:manifiesto_id).count
    @prefacturados_por_manifiesto = del_servicio.where.not(pre_factura_id: nil).group(:manifiesto_id).count
    # C28-14 · Si falta una caja, el manifiesto **se queda** en la lista, y la
    # tarjeta lo dice.
    @faltan_cajas = CajaManifiesto.where(manifiesto_id: ids, recibida_at: nil).group(:manifiesto_id).count

    @pre_facturas_por_manifiesto =
      if @hoja.editar?
        HojaDePreparacion.pre_facturas_editables.where(manifiesto_id: ids)
                         .includes(:cliente).order(:numero).group_by(&:manifiesto_id)
      else
        {}
      end
  end

  def update
    @hoja = @hoja.con(params.fetch(:hoja, {}).permit(:modo, :fecha, :hora, tipo_envio_ids: [], manifiesto_ids: []))
    # Lo que quedó elegido y ya no se ofrece no se guarda: un manifiesto que
    # se terminó de pre-facturar no puede seguir «elegido» escondido.
    @hoja = @hoja.con("manifiesto_ids" => @hoja.manifiestos_elegidos.pluck(:id))
    session[:pf_hoja] = @hoja.to_sesion
    redirect_to hoja_de_preparacion_path
  end

  # PR-P.7 · La hora del aviso, en lote: todas las programadas de un manifiesto
  # (`manifiesto_id`), o todas las que la hoja lista en «editar» (sin él).
  # `ReprogramarAvisos` solo toca las que no avisaron.
  def reprogramar
    scope = HojaDePreparacion.pre_facturas_editables
    scope = scope.where(manifiesto_id: params[:manifiesto_id]) if params[:manifiesto_id].present?
    movidas = ReprogramarAvisos.new(scope, hora: params[:hora], fecha: params[:fecha]).call
    redirect_to hoja_de_preparacion_path,
                notice: movidas.zero? ? "No había pre-facturas programadas para mover." :
                                        "#{movidas} pre-factura#{"s" if movidas != 1} reprogramada#{"s" if movidas != 1} para las #{params[:hora]}."
  rescue ReprogramarAvisos::NoSePuede => e
    redirect_to hoja_de_preparacion_path, alert: e.message
  end

  # PR-P.7 · *"¿Y si se equivocan con F9? — Pueden reversarlo y poner F8."*
  def volver_a_consolidar
    pf = HojaDePreparacion.pre_facturas_editables.find(params[:pre_factura_id])
    pf.volver_a_consolidar!
    redirect_to hoja_de_preparacion_path, notice: "#{pf.numero} volvió a consolidando: no se le avisa al cliente."
  rescue PreFactura::YaAvisada, ActiveRecord::RecordNotFound => e
    redirect_to hoja_de_preparacion_path,
                alert: e.is_a?(PreFactura::YaAvisada) ? e.message : "Esa pre-factura ya no se puede corregir: ya avisó, o no está abierta."
  end

  # Cerrar la hoja: la próxima vez arranca de cero, como «Finalizar sesión»
  # en `/etiquetar`.
  def destroy
    session.delete(:pf_hoja)
    redirect_to hoja_de_preparacion_path, notice: "Hoja de preparación cerrada."
  end

  private

  # La gente de pre-factura: el mismo permiso que `/pre_facturas`.
  def autorizar
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:pre_facturas)
  end

  def cargar_hoja
    @hoja = HojaDePreparacion.desde_sesion(session[:pf_hoja])
  end
end
