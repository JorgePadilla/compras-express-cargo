module Cuenta
  class FinanciamientosController < BaseController
    before_action :set_financiamiento, only: %i[show]

    def index
      @financiamientos = current_cliente.financiamientos.recientes
      @financiamientos = @financiamientos.page(params[:page]).per(12)
    end

    def show
      @cuotas = @financiamiento.financiamiento_cuotas.order(:numero_cuota)
    end

    private

    def set_financiamiento
      @financiamiento = current_cliente.financiamientos.find(params[:id])
    end
  end
end
