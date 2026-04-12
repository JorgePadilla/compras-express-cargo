module Cuenta
  class PreAlertasController < BaseController
    before_action :set_pre_alerta, only: %i[show edit update anular mover_paquete destinos_disponibles]
    helper_method :puede_mover?

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

    def mover_paquete
      pap = @pre_alerta.pre_alerta_paquetes.find(params[:pre_alerta_paquete_id])
      destino = current_cliente.pre_alertas.activas.find(params[:destino_id])

      unless puede_mover?(pap)
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "No se puede mover este paquete."
        return
      end

      unless destino_valido?(pap, destino)
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "Destino no valido para este paquete."
        return
      end

      PreAlertaPaquete.transaction do
        timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
        origen_nota = "[#{timestamp}] Paquete '#{pap.tracking}' movido a #{destino.numero_documento}."
        destino_nota = "[#{timestamp}] Paquete '#{pap.tracking}' recibido de #{@pre_alerta.numero_documento}."

        pap.update!(pre_alerta: destino)

        append_nota(@pre_alerta, origen_nota)
        append_nota(destino, destino_nota)
      end

      redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                  notice: "Paquete movido a #{destino.numero_documento}."
    end

    def destinos_disponibles
      pap = @pre_alerta.pre_alerta_paquetes.find(params[:pre_alerta_paquete_id])

      unless puede_mover?(pap)
        render json: []
        return
      end

      destinos = destinos_para(pap)

      render json: destinos.map { |pa|
        {
          id: pa.id,
          numero_documento: pa.numero_documento,
          titulo: pa.titulo,
          tipo_envio: pa.tipo_envio.nombre,
          paquetes_count: pa.pre_alerta_paquetes.size
        }
      }
    end

    private

    def set_pre_alerta
      @pre_alerta = current_cliente.pre_alertas.find(params[:id])
    end

    def pre_alerta_params
      params.require(:pre_alerta).permit(
        :tipo_envio_id, :consolidado, :con_reempaque, :notas_grupo, :titulo, :proveedor,
        pre_alerta_paquetes_attributes: [:id, :tracking, :descripcion, :instrucciones, :_destroy]
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
          titulo:          params[:titulo],
          proveedor:       params[:proveedor],
          creado_por_tipo: "cliente",
          creado_por_id:   current_cliente.id,
          pre_alerta_paquetes_attributes: [paquete_attrs_from_params]
        )

        if @pre_alerta.save
          if params[:agregar_otro] == "1"
            # Keep wizard session so user can continue adding paquetes in the edit view
            redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                        notice: "¡Paquete agregado a #{@pre_alerta.numero_documento}! Agrega más paquetes abajo."
          elsif !wizard["con_reempaque"]
            # Sin reempaque (CKA/CKM): solo 1 paquete, no necesita ir a editar
            session.delete(:pre_alerta_wizard)
            redirect_to cuenta_root_path,
                        notice: "¡Pre-alerta #{@pre_alerta.numero_documento} registrada exitosamente!"
          else
            session.delete(:pre_alerta_wizard)
            redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                        notice: "¡Pre-alerta #{@pre_alerta.numero_documento} registrada!"
          end
        else
          @wizard = wizard
          @tipo_envios = TipoEnvio.activos.order(:nombre)
          render :new, status: :unprocessable_entity
        end
      end
    end

    def paquete_attrs_from_params
      params.permit(:tracking, :descripcion, :instrucciones).to_h
    end

    # Move rules matrix:
    # - Unlinked (paquete_id nil): can move to any consolidado PA (EXP/CER/CEM), NOT CKA/CKM
    # - Linked with recibido_miami/empacado/enviado_honduras: same tipo_envio consolidado PA only
    # - Linked with en_aduana or later: BLOCKED
    # - Source or dest is CKA/CKM with linked paquete: BLOCKED
    ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras].freeze

    def puede_mover?(pap)
      return false unless @pre_alerta.consolidado? || pap.paquete_id.nil?

      if pap.paquete_id.present?
        return false if @pre_alerta.tipo_envio.single_package?
        ESTADOS_MOVIBLES.include?(pap.paquete.estado)
      else
        true
      end
    end

    def destino_valido?(pap, destino)
      return false if destino.id == @pre_alerta.id
      return false unless destino.consolidado?
      return false if destino.tipo_envio.single_package?

      if pap.paquete_id.present?
        destino.tipo_envio_id == @pre_alerta.tipo_envio_id
      else
        true
      end
    end

    def destinos_para(pap)
      base = current_cliente.pre_alertas.activas
               .where(consolidado: true)
               .where.not(id: @pre_alerta.id)
               .includes(:tipo_envio, :pre_alerta_paquetes)

      # Exclude CKA/CKM (single_package types) — NULL means unlimited, so include those
      base = base.joins(:tipo_envio).where("tipo_envios.max_paquetes_por_accion IS NULL OR tipo_envios.max_paquetes_por_accion != 1")

      if pap.paquete_id.present? && ESTADOS_MOVIBLES.include?(pap.paquete.estado)
        base = base.where(tipo_envio_id: @pre_alerta.tipo_envio_id)
      end

      base.order(:created_at)
    end

    def append_nota(pre_alerta, nota)
      current = pre_alerta.notas_grupo.to_s
      new_notas = current.present? ? "#{current}\n#{nota}" : nota
      pre_alerta.update_column(:notas_grupo, new_notas)
    end
  end
end
