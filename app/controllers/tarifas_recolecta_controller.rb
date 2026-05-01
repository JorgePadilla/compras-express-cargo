# PR-D6.a: CRUD admin del catálogo de tarifas de recolecta por zona.
class TarifasRecolectaController < ApplicationController
  before_action :require_admin
  before_action :set_tarifa, only: %i[edit update]

  def index
    @tarifas = TarifaRecolecta.ordered
  end

  def new
    @tarifa = TarifaRecolecta.new(activo: true, moneda: "USD")
  end

  def create
    @tarifa = TarifaRecolecta.new(tarifa_params)
    if @tarifa.save
      redirect_to tarifas_recolecta_path, notice: "Tarifa creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tarifa.update(tarifa_params)
      redirect_to tarifas_recolecta_path, notice: "Tarifa actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_tarifa
    @tarifa = TarifaRecolecta.find(params[:id])
  end

  def tarifa_params
    params.require(:tarifa_recolecta).permit(:zona, :monto, :moneda, :position, :activo, :notas)
  end
end
