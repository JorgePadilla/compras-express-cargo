module Cuenta
  class PreAlertasController < BaseController
    before_action :set_pre_alerta, only: %i[show edit update anular mover_paquete destinos_disponibles eliminar_paquete paquetes_disponibles agregar_paquete]
    helper_method :puede_mover?, :puede_buscar?

    def index
      @pre_alertas = current_cliente.pre_alertas.includes(:pre_alerta_paquetes, :tipo_envio).activas.recientes
      @pre_alertas = @pre_alertas.buscar(params[:q]) if params[:q].present?
      @pre_alertas = @pre_alertas.by_estado(params[:estado]) if params[:estado].present?
      @pre_alertas = @pre_alertas.page(params[:page]).per(12)
    end

    def show
    end

    def new
      # Resume from a client-side draft: restore wizard session state from URL params
      if params[:resume] == "1" && params[:tipo_envio_id].present?
        tipo = TipoEnvio.activos.find_by(id: params[:tipo_envio_id])
        if tipo
          session[:pre_alerta_wizard] = {
            "tipo_envio_id" => tipo.id,
            "con_reempaque" => tipo.con_reempaque,
            "consolidado"   => params[:consolidado] == "1"
          }
        end
      end

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
      if @pre_alerta.finalizado?
        if params[:autosave] == "true"
          render json: { status: "error", errors: ["Esta pre-alerta ya fue finalizada."] }, status: :unprocessable_entity
          return
        end
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "Esta pre-alerta ya fue finalizada y no se puede modificar."
        return
      end

      # ── Autosave (JSON) ──
      if params[:autosave] == "true"
        if @pre_alerta.update(pre_alerta_params)
          new_paquetes = {}
          pap_params = params.dig(:pre_alerta, :pre_alerta_paquetes_attributes)
          if pap_params
            pap_params.each do |index, attrs|
              next if attrs[:id].present? || attrs[:_destroy] == "1"
              pap = @pre_alerta.pre_alerta_paquetes.find_by(
                tracking: attrs[:tracking]&.strip&.upcase
              )
              new_paquetes[index] = pap.id if pap
            end
          end
          render json: { status: "saved", new_paquetes: new_paquetes }
        else
          render json: { status: "error", errors: @pre_alerta.errors.full_messages },
                 status: :unprocessable_entity
        end
        return
      end

      notificar = params[:notificar] == "true"
      finalizar = params[:finalizar] == "true" && @pre_alerta.consolidado?

      if @pre_alerta.update(pre_alerta_params)
        @pre_alerta.update_column(:notificado, true) if notificar

        if finalizar
          @pre_alerta.update_column(:finalizado, true)
          redirect_to cuenta_root_path,
                      notice: "¡Consolidación finalizada! Pre-alerta #{@pre_alerta.numero_documento} guardada."
          return
        end

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

      if @pre_alerta.finalizado?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "No se puede mover paquetes desde una pre-alerta finalizada."
        return
      end

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
        paq_desc = pap.descripcion.presence || pap.tracking.presence || "sin descripcion"
        origen_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) movido a #{destino.numero_documento} — #{destino.titulo}."
        destino_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) recibido de #{@pre_alerta.numero_documento} — #{@pre_alerta.titulo}."

        pap.update!(pre_alerta: destino)

        @pre_alerta.append_historial!(origen_entry)
        destino.append_historial!(destino_entry)
      end

      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later
      PreAlertaMailer.confirmacion(destino).deliver_later

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
        te = pa.tipo_envio
        modalidad = te.modalidad&.capitalize || "—"
        desc = te.con_reempaque ? "#{modalidad} con Reempaque" : "#{modalidad} sin Reempaque"

        {
          id: pa.id,
          numero_documento: pa.numero_documento,
          titulo: pa.titulo,
          tipo_envio: te.nombre,
          tipo_envio_descripcion: desc,
          paquetes_count: pa.pre_alerta_paquetes.size,
          created_at: pa.created_at.strftime("%d/%m/%Y")
        }
      }
    end

    def eliminar_paquete
      pap = @pre_alerta.pre_alerta_paquetes.find(params[:pre_alerta_paquete_id])

      if @pre_alerta.finalizado?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "No se puede eliminar paquetes de una pre-alerta finalizada."
        return
      end

      if pap.paquete_id.present?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), alert: "No se puede eliminar un paquete vinculado."
        return
      end

      timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
      paq_desc = pap.descripcion.presence || pap.tracking.presence || "sin descripcion"
      @pre_alerta.append_historial!("[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) eliminado.")

      pap.destroy!
      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.remove("paquete_row_#{pap.id}")
        }
        format.html {
          redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: "Paquete eliminado."
        }
      end
    end

    def paquetes_disponibles
      unless puede_buscar?
        render json: []
        return
      end

      paquetes = candidatos_para_buscar

      render json: paquetes.map { |p|
        pap_origen = p.pre_alerta_paquetes.joins(:pre_alerta)
                       .where(pre_alertas: { consolidado: true, finalizado: false })
                       .where.not(pre_alertas: { id: @pre_alerta.id })
                       .first
        origen_info = if pap_origen
          {
            numero: pap_origen.pre_alerta.numero_documento,
            titulo: pap_origen.pre_alerta.titulo,
            pap_id: pap_origen.id
          }
        end

        {
          id: p.id,
          tracking: p.tracking,
          guia: p.guia,
          descripcion: p.descripcion.presence || "—",
          estado: p.estado,
          estado_label: p.estado.humanize,
          peso_cobrar: p.peso_cobrar&.to_f,
          fecha_recibido: p.fecha_recibido_miami&.strftime("%d/%m/%Y"),
          tipo_envio: p.tipo_envio&.nombre || "—",
          origen: origen_info
        }
      }
    end

    def agregar_paquete
      paquete = current_cliente.paquetes.find(params[:paquete_id])

      unless puede_buscar?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "No se puede agregar paquetes a esta pre-alerta."
        return
      end

      unless paquete.tipo_envio_id == @pre_alerta.tipo_envio_id &&
             ESTADOS_MOVIBLES.include?(paquete.estado)
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "El paquete no cumple los requisitos para ser agregado."
        return
      end

      # Buscar CUALQUIER PAP vinculado a otra PA activa (no solo consolidando) para
      # poder detectar si el origen es CKA/CKM y bloquear el pull.
      pap_origen = paquete.pre_alerta_paquetes
                          .joins(:pre_alerta)
                          .where(pre_alertas: { deleted_at: nil })
                          .where.not(pre_alertas: { estado: "anulado" })
                          .where.not(pre_alertas: { id: @pre_alerta.id })
                          .first

      blocked_cka = false
      PreAlertaPaquete.transaction do
        timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
        paq_desc = paquete.descripcion.presence || paquete.tracking

        if pap_origen
          if pap_origen.pre_alerta.tipo_envio.single_package?
            blocked_cka = true
            raise ActiveRecord::Rollback
          end

          source_pa = pap_origen.pre_alerta
          notas_origen = source_pa.notas_grupo.presence
          notas_suffix = notas_origen ? " Notas del grupo origen: \"#{notas_origen}\"." : ""

          origen_entry  = "[#{timestamp}] Paquete '#{paq_desc}' (#{paquete.tracking}) jalado a #{@pre_alerta.numero_documento} — #{@pre_alerta.titulo}.#{notas_suffix}"
          destino_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{paquete.tracking}) jalado de #{source_pa.numero_documento} — #{source_pa.titulo}.#{notas_suffix}"

          pap_origen.update!(pre_alerta: @pre_alerta)
          source_pa.append_historial!(origen_entry)
          @pre_alerta.append_historial!(destino_entry)

          PreAlertaMailer.confirmacion(source_pa).deliver_later
        else
          @pre_alerta.pre_alerta_paquetes.create!(
            paquete: paquete,
            tracking: paquete.tracking,
            descripcion: paq_desc,
            fecha: Date.current
          )
          destino_entry = "[#{timestamp}] Paquete suelto '#{paq_desc}' (#{paquete.tracking}) agregado desde bodega."
          @pre_alerta.append_historial!(destino_entry)
        end
      end

      if blocked_cka
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "No se puede jalar un paquete de una pre-alerta CKA/CKM."
        return
      end

      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later

      redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                  notice: "Paquete agregado a la pre-alerta."
    rescue ActiveRecord::RecordNotFound
      redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                  alert: "Paquete no encontrado."
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
            redirect_to edit_cuenta_pre_alerta_path(@pre_alerta, agregar: 1),
                        notice: "¡Paquete agregado a #{@pre_alerta.numero_documento}! Agrega más paquetes abajo."
          else
            # All other cases: save, notify, go home with success modal
            session.delete(:pre_alerta_wizard)
            @pre_alerta.update_column(:notificado, true)
            PreAlertaMailer.confirmacion(@pre_alerta).deliver_later
            redirect_to cuenta_root_path,
                        flash: { success_modal: "¡Pre-alerta #{@pre_alerta.numero_documento} registrada exitosamente!" }
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
    # - Source or dest is CKA/CKM: BLOCKED (both linked and unlinked)
    ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras].freeze

    def puede_mover?(pap)
      return false if @pre_alerta.finalizado?
      return false if @pre_alerta.tipo_envio.single_package? # CKA/CKM never allow moves

      if pap.paquete_id.present?
        ESTADOS_MOVIBLES.include?(pap.paquete.estado)
      else
        true # unlinked paquetes on non-CKA/CKM PAs can always move
      end
    end

    def destino_valido?(pap, destino)
      return false if destino.id == @pre_alerta.id
      return false unless destino.consolidado?
      return false if destino.finalizado?
      return false if destino.tipo_envio.single_package?

      if pap.paquete_id.present?
        destino.tipo_envio_id == @pre_alerta.tipo_envio_id
      else
        true
      end
    end

    def destinos_para(pap)
      base = current_cliente.pre_alertas.activas
               .where(consolidado: true, finalizado: false)
               .where.not(id: @pre_alerta.id)
               .includes(:tipo_envio, :pre_alerta_paquetes)

      # Exclude CKA/CKM (single_package types) — NULL means unlimited, so include those
      base = base.joins(:tipo_envio).where("tipo_envios.max_paquetes_por_accion IS NULL OR tipo_envios.max_paquetes_por_accion != 1")

      if pap.paquete_id.present? && ESTADOS_MOVIBLES.include?(pap.paquete.estado)
        base = base.where(tipo_envio_id: @pre_alerta.tipo_envio_id)
      end

      base.order(created_at: :desc)
    end

    def puede_buscar?
      return false if @pre_alerta.finalizado?
      return false unless @pre_alerta.consolidando?
      return false if @pre_alerta.tipo_envio.single_package?
      true
    end

    def candidatos_para_buscar
      tipo_id = @pre_alerta.tipo_envio_id

      # Paquetes sueltos del cliente, mismo tipo_envio, estado movible
      sueltos = current_cliente.paquetes
                  .sin_pre_alerta
                  .where(estado: ESTADOS_MOVIBLES)
                  .where(tipo_envio_id: tipo_id)

      # Paquetes vinculados a otras PAs consolidando del cliente (NO CKA/CKM)
      vinculados = current_cliente.paquetes
                     .where(estado: ESTADOS_MOVIBLES)
                     .where(tipo_envio_id: tipo_id)
                     .joins(pre_alerta_paquetes: { pre_alerta: :tipo_envio })
                     .where(pre_alertas: { consolidado: true, finalizado: false })
                     .where.not(pre_alertas: { id: @pre_alerta.id })
                     .where("tipo_envios.max_paquetes_por_accion IS NULL OR tipo_envios.max_paquetes_por_accion != 1")

      (sueltos.to_a + vinculados.to_a).uniq
        .sort_by { |p| p.fecha_recibido_miami || p.created_at }
        .reverse
    end
  end
end
