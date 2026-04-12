module Cuenta
  class CotizacionesController < BaseController
    before_action :set_cotizacion, only: %i[show pdf aceptar rechazar]

    def index
      @cotizaciones = current_cliente.cotizaciones.where.not(estado: "borrador").recientes
      @cotizaciones = @cotizaciones.page(params[:page]).per(12)
    end

    def show
    end

    def pdf
      send_data CotizacionPdf.new(@cotizacion).render,
                filename: "cotizacion-#{@cotizacion.numero}.pdf",
                type: "application/pdf",
                disposition: "inline"
    end

    def aceptar
      if @cotizacion.aceptar!
        CotizacionMailer.aceptada(@cotizacion).deliver_later
        redirect_to cuenta_cotizacion_path(@cotizacion), notice: "Cotizacion aceptada."
      else
        redirect_to cuenta_cotizacion_path(@cotizacion), alert: "No se puede aceptar esta cotizacion."
      end
    end

    def rechazar
      if @cotizacion.rechazar!
        redirect_to cuenta_cotizacion_path(@cotizacion), notice: "Cotizacion rechazada."
      else
        redirect_to cuenta_cotizacion_path(@cotizacion), alert: "No se puede rechazar esta cotizacion."
      end
    end

    private

    def set_cotizacion
      @cotizacion = current_cliente.cotizaciones.where.not(estado: "borrador").find(params[:id])
    end
  end
end
