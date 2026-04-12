class EntregasController < ApplicationController
  before_action :require_feature_access
  before_action :set_entrega, only: %i[show edit update despachar entregar anular]

  def index
    @entregas = Entrega.includes(:cliente, :repartidor, :creado_por).recientes
    @entregas = apply_filters(@entregas)
    @entregas = @entregas.page(params[:page]).per(25)
  end

  def new
    @cliente = Cliente.find(params[:cliente_id]) if params[:cliente_id].present?
    if @cliente
      @paquetes = @cliente.paquetes.entregables.includes(:tipo_envio)
      @entrega = Entrega.new(cliente: @cliente)
    end
  end

  def create
    @cliente = Cliente.find(params[:entrega][:cliente_id])
    paquete_ids = params[:paquete_ids] || []

    @entrega = Entrega.build_from_paquetes(
      @cliente, paquete_ids,
      tipo_entrega: entrega_params[:tipo_entrega],
      receptor_nombre: entrega_params[:receptor_nombre],
      receptor_identidad: entrega_params[:receptor_identidad],
      direccion_entrega: entrega_params[:direccion_entrega],
      repartidor_id: entrega_params[:repartidor_id],
      creado_por: Current.user,
      notas: entrega_params[:notas]
    )

    if @entrega.save
      @entrega.paquetes.each { |p| p.update!(entrega_id: @entrega.id) }
      redirect_to @entrega, notice: "Entrega #{@entrega.numero} creada exitosamente."
    else
      @paquetes = @cliente.paquetes.entregables.includes(:tipo_envio)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    redirect_to @entrega, alert: "Solo se puede editar una entrega pendiente." unless @entrega.pendiente?
  end

  def update
    unless @entrega.pendiente?
      redirect_to @entrega, alert: "Solo se puede editar una entrega pendiente." and return
    end

    if @entrega.update(entrega_update_params)
      redirect_to @entrega, notice: "Entrega actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def despachar
    if @entrega.despachar!
      redirect_to @entrega, notice: "Entrega despachada. Paquetes en reparto."
    else
      redirect_to @entrega, alert: "No se pudo despachar la entrega."
    end
  end

  def entregar
    if @entrega.entregar!
      redirect_to @entrega, notice: "Entrega completada exitosamente."
    else
      redirect_to @entrega, alert: "No se pudo completar la entrega."
    end
  end

  def anular
    if @entrega.anular!
      redirect_to entregas_path, notice: "Entrega anulada. Paquetes devueltos a facturado."
    else
      redirect_to @entrega, alert: "No se puede anular una entrega ya entregada."
    end
  end

  def entregables
    cliente = Cliente.find(params[:cliente_id])
    paquetes = cliente.paquetes.entregables.includes(:tipo_envio)
    render json: paquetes.map { |p|
      { id: p.id, guia: p.guia, tracking: p.tracking, descripcion: p.descripcion,
        peso: p.peso_cobrar.to_f, tipo_envio: p.tipo_envio&.nombre }
    }
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:entregas)
  end

  def set_entrega
    @entrega = Entrega.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_repartidor(params[:repartidor_id]) if params[:repartidor_id].present?
    scope
  end

  def entrega_params
    params.require(:entrega).permit(:cliente_id, :tipo_entrega, :receptor_nombre, :receptor_identidad, :direccion_entrega, :repartidor_id, :notas)
  end

  def entrega_update_params
    params.require(:entrega).permit(:receptor_nombre, :receptor_identidad, :direccion_entrega, :repartidor_id, :notas, :tipo_entrega)
  end
end
