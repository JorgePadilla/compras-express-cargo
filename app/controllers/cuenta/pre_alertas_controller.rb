module Cuenta
  class PreAlertasController < BaseController
    before_action :set_pre_alerta, only: %i[show edit update anular]

    def index
      @pre_alertas = current_cliente.pre_alertas.includes(:pre_alerta_paquetes, :tipo_envio).activas.recientes
      @pre_alertas = @pre_alertas.buscar(params[:q]) if params[:q].present?
      @pre_alertas = @pre_alertas.by_estado(params[:estado]) if params[:estado].present?
      @pre_alertas = @pre_alertas.page(params[:page]).per(12)
    end

    def show
    end

    def new
      @pre_alerta = current_cliente.pre_alertas.build
      @wizard = session[:pre_alerta_wizard] || {}
      @pre_alerta.con_reempaque = @wizard["con_reempaque"]
      @pre_alerta.consolidado = @wizard["consolidado"]
      @pre_alerta.tipo_envio_id = @wizard["tipo_envio_id"]

      @tipo_envios = TipoEnvio.activos.order(:nombre)
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
        pre_alerta_paquetes_attributes: [:id, :tracking, :descripcion, :valor_declarado, :peso, :retener_miami, :fecha, :instrucciones, :_destroy]
      )
    end

    def handle_wizard_step
      session[:pre_alerta_wizard] ||= {}
      step = params[:wizard_step].to_i

      case step
      when 1  # Servicio
        tipo = TipoEnvio.activos.find_by(id: params[:tipo_envio_id])
        return redirect_to(new_cuenta_pre_alerta_path(step: 1), alert: "Selecciona un servicio") unless tipo

        session[:pre_alerta_wizard]["tipo_envio_id"] = tipo.id
        session[:pre_alerta_wizard]["con_reempaque"] = tipo.con_reempaque

        if tipo.consolidable
          redirect_to new_cuenta_pre_alerta_path(step: 2)
        else
          # CKA/CKM are never consolidable — go straight to step 3
          session[:pre_alerta_wizard]["consolidado"] = false
          redirect_to new_cuenta_pre_alerta_path(step: 3)
        end

      when 2  # Consolidación (only reached for EXPRESS/CER/CEM)
        session[:pre_alerta_wizard]["consolidado"] = params[:consolidado] == "1"
        redirect_to new_cuenta_pre_alerta_path(step: 3)

      when 3  # Datos del paquete → crear PreAlerta + primer paquete
        wizard = session[:pre_alerta_wizard]
        @pre_alerta = current_cliente.pre_alertas.build(
          tipo_envio_id:   wizard["tipo_envio_id"],
          con_reempaque:   wizard["con_reempaque"],
          consolidado:     wizard["consolidado"],
          creado_por_tipo: "cliente",
          creado_por_id:   current_cliente.id,
          pre_alerta_paquetes_attributes: [paquete_attrs_from_params]
        )

        if @pre_alerta.save
          session.delete(:pre_alerta_wizard)
          redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                      notice: "¡Pre-alerta #{@pre_alerta.numero_documento} registrada! Puedes agregar más paquetes abajo."
        else
          @wizard = wizard
          @tipo_envios = TipoEnvio.activos.order(:nombre)
          render :new, status: :unprocessable_entity
        end
      end
    end

    def paquete_attrs_from_params
      params.permit(:tracking, :descripcion, :valor_declarado, :peso, :instrucciones).to_h
    end
  end
end
