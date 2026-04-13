module Cuenta
  class FacturasController < BaseController
    before_action :set_factura, only: [:show, :pdf]

    def index
      @ventas = current_cliente.ventas.includes(:venta_items).activas.recientes
      @ventas = @ventas.by_estado(params[:estado]) if params[:estado].present?
      @ventas = @ventas.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data VentaPdf.new(@venta).render,
                filename: "factura-#{@venta.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    def set_factura
      @venta = current_cliente.ventas.find(params[:id])
    end
  end
end
