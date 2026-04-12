module Cuenta
  class RecibosController < BaseController
    before_action :set_recibo, only: [:show, :pdf]

    def index
      @recibos = current_cliente.recibos.includes(:venta, :pago).recientes
      @recibos = @recibos.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data ReciboPdf.new(@recibo).render,
                filename: "recibo-#{@recibo.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    def set_recibo
      @recibo = current_cliente.recibos.find(params[:id])
    end
  end
end
