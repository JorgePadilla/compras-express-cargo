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
