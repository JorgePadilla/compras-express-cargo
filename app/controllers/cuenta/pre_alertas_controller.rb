module Cuenta
  class PreAlertasController < BaseController
    before_action :set_pre_alerta, only: %i[show edit update anular]

    def index
      @pre_alertas = current_cliente.pre_alertas.activas.recientes
      @pre_alertas = @pre_alertas.buscar(params[:q]) if params[:q].present?
      @pre_alertas = @pre_alertas.by_estado(params[:estado]) if params[:estado].present?
      @pre_alertas = @pre_alertas.page(params[:page]).per(12)
    end

    def show
    end

    def new
      @pre_alerta = current_cliente.pre_alertas.build
      @tipo_envios = TipoEnvio.where(activo: true).order(:nombre)

      if session[:pre_alerta_wizard].present?
        wizard = session[:pre_alerta_wizard]
        @pre_alerta.con_reempaque = wizard["con_reempaque"]
        @pre_alerta.consolidado = wizard["consolidado"]
        @pre_alerta.tipo_envio_id = wizard["tipo_envio_id"]
      end
    end

    def create
      if params[:wizard_step].present?
        handle_wizard_step
      else
        @pre_alerta = current_cliente.pre_alertas.build(pre_alerta_params)
        @pre_alerta.creado_por_tipo = "cliente"
        @pre_alerta.creado_por_id = current_cliente.id

        if @pre_alerta.save
          session.delete(:pre_alerta_wizard)
          redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: "Pre-alerta creada exitosamente."
        else
          @tipo_envios = TipoEnvio.where(activo: true).order(:nombre)
          render :new, status: :unprocessable_entity
        end
      end
    end

    def edit
      @pre_alerta.pre_alerta_paquetes.build if @pre_alerta.pre_alerta_paquetes.empty?
    end

    def update
      notificar = params[:notificar] == "true"

      if @pre_alerta.update(pre_alerta_params)
        @pre_alerta.update_column(:notificado, true) if notificar

        respond_to do |format|
          format.html { redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: "Pre-alerta actualizada." }
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.update("pre_alerta_header", partial: "cuenta/pre_alertas/header", locals: { pre_alerta: @pre_alerta }),
              turbo_stream.update("flash", partial: "shared/flash", locals: { notice: notificar ? "Guardado y notificado." : "Guardado." })
            ]
          }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def anular
      @pre_alerta.anular!
      redirect_to cuenta_pre_alertas_path, notice: "Pre-alerta anulada."
    end

    private

    def set_pre_alerta
      @pre_alerta = current_cliente.pre_alertas.find(params[:id])
    end

    def pre_alerta_params
      params.require(:pre_alerta).permit(
        :tipo_envio_id, :consolidado, :con_reempaque, :notas_grupo,
        pre_alerta_paquetes_attributes: [:id, :tracking, :descripcion, :retener_miami, :fecha, :_destroy]
      )
    end

    def handle_wizard_step
      session[:pre_alerta_wizard] ||= {}
      step = params[:wizard_step].to_i

      case step
      when 1
        session[:pre_alerta_wizard]["con_reempaque"] = params[:con_reempaque] == "1"
        redirect_to new_cuenta_pre_alerta_path(step: 2)
      when 2
        session[:pre_alerta_wizard]["consolidado"] = params[:consolidado] == "1"
        redirect_to new_cuenta_pre_alerta_path(step: 3)
      when 3
        session[:pre_alerta_wizard]["tipo_envio_id"] = params[:tipo_envio_id]
        @pre_alerta = current_cliente.pre_alertas.build(
          con_reempaque: session[:pre_alerta_wizard]["con_reempaque"],
          consolidado: session[:pre_alerta_wizard]["consolidado"],
          tipo_envio_id: session[:pre_alerta_wizard]["tipo_envio_id"],
          creado_por_tipo: "cliente",
          creado_por_id: current_cliente.id
        )

        if @pre_alerta.save
          session.delete(:pre_alerta_wizard)
          redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: "Pre-alerta creada. Agrega tus paquetes."
        else
          @tipo_envios = TipoEnvio.where(activo: true).order(:nombre)
          render :new, status: :unprocessable_entity
        end
      end
    end
  end
end
