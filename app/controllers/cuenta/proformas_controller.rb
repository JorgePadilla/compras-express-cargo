module Cuenta
  class ProformasController < BaseController
    before_action :set_proforma, only: %i[show pdf]

    def index
      @proformas = current_cliente.ventas.proformas.recientes
      @proformas = @proformas.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data VentaPdf.new(@proforma).render,
                filename: "proforma-#{@proforma.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    private

    def set_proforma
      @proforma = current_cliente.ventas.proformas.find(params[:id])
    end
  end
end
