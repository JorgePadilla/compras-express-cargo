module Cuenta
  class EntregasController < BaseController
    before_action :set_entrega, only: [:show]

    def index
      @entregas = current_cliente.entregas.includes(:repartidor, :paquetes).recientes
      @entregas = @entregas.by_estado(params[:estado]) if params[:estado].present?
      @entregas = @entregas.page(params[:page]).per(12)
    end

    def show
    end

    private

    def set_entrega
      @entrega = current_cliente.entregas.find(params[:id])
    end
  end
end
