module Cuenta
  class NotasDebitoController < BaseController
    before_action :set_nota_debito, only: %i[show pdf]

    def index
      @notas_debito = current_cliente.notas_debito.emitidas.includes(:venta).recientes
      @notas_debito = @notas_debito.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data NotaDebitoPdf.new(@nota_debito).render,
                filename: "ND-#{@nota_debito.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    def set_nota_debito
      @nota_debito = current_cliente.notas_debito.emitidas.find(params[:id])
    end
  end
end
