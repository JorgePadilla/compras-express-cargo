class ManifiestosController < ApplicationController
  before_action :authorize_manifiestos
  before_action :set_manifiesto, only: [ :show, :edit, :update, :add_paquete, :remove_paquete, :enviar ]

  def index
    @manifiestos = Manifiesto.activos.includes(:empresa_manifiesto).order(created_at: :desc)
    @manifiestos = @manifiestos.buscar(params[:q]) if params[:q].present?
    @manifiestos = @manifiestos.by_estado(params[:estado]) if params[:estado].present?
    @manifiestos = @manifiestos.page(params[:page]).per(25)
  end

  def show
    @paquetes = @manifiesto.paquetes.includes(:cliente).order(:created_at)
  end

  def new
    @manifiesto = Manifiesto.new
    @empresas = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def create
    @manifiesto = Manifiesto.new(manifiesto_params)
    @manifiesto.user = Current.user

    if @manifiesto.save
      redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} creado exitosamente."
    else
      @empresas = EmpresaManifiesto.activos.order(:nombre)
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @empresas = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def update
    if @manifiesto.update(manifiesto_params)
      redirect_to @manifiesto, notice: "Manifiesto actualizado exitosamente."
    else
      @empresas = EmpresaManifiesto.activos.order(:nombre)
      @tipo_envios = TipoEnvio.activos.order(:nombre)
      render :edit, status: :unprocessable_entity
    end
  end

  def add_paquete
    paquete = Paquete.find(params[:paquete_id])
    paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} agregado al manifiesto.")
  end

  def remove_paquete
    paquete = @manifiesto.paquetes.find(params[:paquete_id])
    paquete.update!(manifiesto: nil, estado: "empacado")
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} removido del manifiesto.")
  end

  def enviar
    @manifiesto.enviar!
    redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} enviado exitosamente."
  end

  private

  def authorize_manifiestos
    require_role(:supervisor_miami, :digitador_miami)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  def respond_to_paquete_change(message)
    @paquetes = @manifiesto.paquetes.includes(:cliente).order(:created_at)
    @manifiesto.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("manifiesto-paquetes", partial: "manifiestos/paquetes_table", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
      format.html { redirect_to @manifiesto, notice: message }
    end
  end

  def manifiesto_params
    params.require(:manifiesto).permit(
      :numero, :numero_caja, :numero_guia, :empresa_manifiesto_id,
      :tipo_envio, :expedido_por
    )
  end
end
