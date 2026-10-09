module Cuenta
  class DashboardController < BaseController
    def index
      @cliente = current_cliente
      @pre_alertas_count = @cliente.pre_alertas.activas.count
      @paquetes_recientes = @cliente.paquetes.activos
                                    .includes(:sucursal, :sucursal_destino)
                                    .order(created_at: :desc).limit(5)
    end
  end
end
