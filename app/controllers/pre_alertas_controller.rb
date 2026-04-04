class PreAlertasController < ApplicationController
  before_action :set_pre_alerta, only: %i[show edit update anular]

  def index
    @pre_alertas = base_scope.includes(:cliente, :tipo_envio, :pre_alerta_paquetes).recientes
    @pre_alertas = apply_filters(@pre_alertas)
    @pre_alertas = @pre_alertas.page(params[:page]).per(25)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def show
  end

  def new
    @pre_alerta = PreAlerta.new
    @pre_alerta.pre_alerta_paquetes.build
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def create
    @pre_alerta = PreAlerta.new(pre_alerta_params)
    @pre_alerta.creado_por_tipo = "usuario"
    @pre_alerta.creado_por_id = Current.user.id

    if @pre_alerta.save
      redirect_to pre_alerta_path(@pre_alerta), notice: "Pre-Alerta #{@pre_alerta.numero_documento} creada exitosamente."
    else
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def update
    if @pre_alerta.update(pre_alerta_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("pre_alerta_header", partial: "pre_alertas/header", locals: { pre_alerta: @pre_alerta }),
            turbo_stream.update("flash", partial: "shared/flash", locals: { notice: "Pre-Alerta actualizada." })
          ]
        end
        format.html { redirect_to pre_alerta_path(@pre_alerta), notice: "Pre-Alerta actualizada." }
      end
    else
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      render :edit, status: :unprocessable_entity
    end
  end

  def anular
    @pre_alerta.anular!
    redirect_to pre_alertas_path, notice: "Pre-Alerta #{@pre_alerta.numero_documento} anulada."
  end

  def clean_empty
    count = PreAlerta.activas.vacias.where(created_at: ...30.days.ago).count
    PreAlerta.activas.vacias.where(created_at: ...30.days.ago).find_each(&:soft_delete!)
    redirect_to pre_alertas_path, notice: "#{count} pre-alertas vacias eliminadas."
  end

  private

  def set_pre_alerta
    @pre_alerta = PreAlerta.find(params[:id])
  end

  def base_scope
    if params[:incluir_anulados] == "1" || params[:solo_anulados] == "1"
      PreAlerta.where(deleted_at: nil)
    else
      PreAlerta.activas
    end
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_tipo_envio(params[:tipo_envio_id]) if params[:tipo_envio_id].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    scope = scope.where(consolidado: true) if params[:solo_consolidados] == "1"
    scope = scope.solo_anulados if params[:solo_anulados] == "1"
    scope = scope.vacias if params[:solo_vacias] == "1"
    scope
  end

  def pre_alerta_params
    params.require(:pre_alerta).permit(
      :cliente_id, :tipo_envio_id, :consolidado, :con_reempaque,
      :notas_grupo, :estado,
      pre_alerta_paquetes_attributes: %i[id tracking descripcion retener_miami fecha _destroy]
    )
  end
end
