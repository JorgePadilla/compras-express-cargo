module Cuenta
  class NotasCreditoController < BaseController
    before_action :set_nota_credito, only: %i[show pdf]

    def index
      @notas_credito = current_cliente.notas_credito.emitidas.includes(:venta).recientes
      @notas_credito = @notas_credito.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data NotaCreditoPdf.new(@nota_credito).render,
                filename: "NC-#{@nota_credito.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    def set_nota_credito
      @nota_credito = current_cliente.notas_credito.emitidas.find(params[:id])
    end
  end
end
