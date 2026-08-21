module Cuenta
  class PreAlertasController < BaseController
    before_action :set_pre_alerta, only: %i[show edit update anular mover_paquete destinos_disponibles eliminar_paquete paquetes_disponibles agregar_paquete]
    helper_method :puede_mover?, :puede_eliminar?, :puede_editar?, :puede_buscar?

    def index
      @pre_alertas = current_cliente.pre_alertas.includes(:pre_alerta_paquetes, :tipo_envio).activas.recientes
      @pre_alertas = @pre_alertas.buscar(params[:q]) if params[:q].present?
      @pre_alertas = @pre_alertas.by_estado(params[:estado]) if params[:estado].present?
      @pre_alertas = @pre_alertas.page(params[:page]).per(per_page_sanitized)
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
            # `con_reempaque` ya no viaja en el wizard: lo deriva el modelo del
            # servicio. Una clave muerta en la sesión confunde al que la lea después.
            "consolidado"   => params[:consolidado] == "1"
          }
        end
      end

      @pre_alerta = current_cliente.pre_alertas.build
      @wizard = session[:pre_alerta_wizard] || {}
      # `con_reempaque` sale del servicio; lo pone el modelo.
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

          if @pre_alerta.reload.deleted_at.present?
            flash[:notice] = "La pre-alerta quedó vacía y fue eliminada."
            render json: { status: "saved", redirect: cuenta_pre_alertas_path }
            return
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

      origen_quedo_vacia = false

      PreAlertaPaquete.transaction do
        timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
        paq_desc = pap.descripcion.presence || pap.tracking.presence || "sin descripcion"
        notas_origen = @pre_alerta.notas_grupo.presence
        notas_suffix = notas_origen ? " Notas del grupo origen: \"#{notas_origen}\"." : ""

        origen_entry  = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) movido a #{destino.numero_documento} — #{destino.titulo}.#{notas_suffix}"
        destino_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) recibido de #{@pre_alerta.numero_documento} — #{@pre_alerta.titulo}.#{notas_suffix}"

        pap.update!(pre_alerta: destino)

        @pre_alerta.append_historial!(origen_entry)
        destino.append_historial!(destino_entry)

        if @pre_alerta.pre_alerta_paquetes.reload.empty?
          @pre_alerta.soft_delete!
          origen_quedo_vacia = true
        end
      end

      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later unless origen_quedo_vacia
      PreAlertaMailer.confirmacion(destino).deliver_later

      if origen_quedo_vacia
        redirect_to cuenta_pre_alertas_path,
                    notice: "Paquete movido a #{destino.numero_documento}. La pre-alerta origen quedó vacía y fue eliminada."
      else
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    notice: "Paquete movido a #{destino.numero_documento}."
      end
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
          consolidado: pa.consolidado,
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
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "No se puede eliminar: el paquete ya fue recibido en nuestra bodega."
        return
      end

      timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
      paq_desc = pap.descripcion.presence || pap.tracking.presence || "sin descripcion"
      historial_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) eliminado."
      @pre_alerta.append_historial!(historial_entry)

      pap.destroy!

      quedo_vacia = @pre_alerta.reload.deleted_at.present?
      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later unless quedo_vacia

      respond_to do |format|
        format.turbo_stream {
          if quedo_vacia
            redirect_to cuenta_pre_alertas_path,
                        notice: "Paquete eliminado. La pre-alerta quedó vacía y fue eliminada."
          else
            render turbo_stream: turbo_stream.remove("paquete_row_#{pap.id}")
          end
        }
        format.html {
          if quedo_vacia
            redirect_to cuenta_pre_alertas_path,
                        notice: "Paquete eliminado. La pre-alerta quedó vacía y fue eliminada."
          else
            redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: "Paquete eliminado."
          end
        }
      end
    end

    def paquetes_disponibles
      unless puede_buscar?
        render json: []
        return
      end

      fisicos = candidatos_para_buscar.map do |p|
        pap_origen = p.pre_alerta_paquetes.joins(:pre_alerta)
                       .where(pre_alertas: { consolidado: true, finalizado: false })
                       .where.not(pre_alertas: { id: @pre_alerta.id })
                       .first
        origen_info = if pap_origen
          {
            numero: pap_origen.pre_alerta.numero_documento,
            titulo: pap_origen.pre_alerta.titulo,
            pap_id: pap_origen.id,
            paquetes_count: pap_origen.pre_alerta.pre_alerta_paquetes.size
          }
        end

        {
          kind: "paquete",
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
      end

      placeholders = placeholders_para_buscar.map do |pap|
        source_pa = pap.pre_alerta
        {
          kind: "placeholder",
          id: pap.id,
          tracking: pap.tracking,
          guia: nil,
          descripcion: pap.descripcion.presence || "—",
          estado: "pre_alerta",
          estado_label: "Pre Alerta",
          peso_cobrar: nil,
          fecha_recibido: nil,
          tipo_envio: source_pa.tipo_envio&.nombre || "—",
          origen: {
            numero: source_pa.numero_documento,
            titulo: source_pa.titulo,
            pap_id: pap.id,
            paquetes_count: source_pa.pre_alerta_paquetes.size
          }
        }
      end

      render json: fisicos + placeholders
    end

    def agregar_paquete
      unless puede_buscar?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "No se puede agregar paquetes a esta pre-alerta."
        return
      end

      if params[:pap_id].present? && params[:paquete_id].blank?
        agregar_placeholder(params[:pap_id])
        return
      end

      paquete = current_cliente.paquetes.find(params[:paquete_id])

      if paquete.tipo_envio_id != @pre_alerta.tipo_envio_id
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "El tipo de envío del paquete (#{paquete.tipo_envio.nombre}) no coincide con esta pre-alerta (#{@pre_alerta.tipo_envio.nombre})."
        return
      end

      unless ESTADOS_MOVIBLES.include?(paquete.estado)
        estado_humano = paquete.estado.to_s.tr("_", " ").capitalize
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "Este paquete ya se encuentra en #{estado_humano} y no puede moverse. Por favor comuníquese con las oficinas de Compras Express."
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
      blocked_sin_consolidar = false
      source_pa = nil
      source_pa_vacia = false
      PreAlertaPaquete.transaction do
        timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
        paq_desc = paquete.descripcion.presence || paquete.tracking

        if pap_origen
          if pap_origen.pre_alerta.tipo_envio.single_package?
            blocked_cka = true
            raise ActiveRecord::Rollback
          end

          unless @pre_alerta.consolidando?
            blocked_sin_consolidar = true
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

          if source_pa.pre_alerta_paquetes.reload.empty?
            source_pa.soft_delete!
            source_pa_vacia = true
          else
            PreAlertaMailer.confirmacion(source_pa).deliver_later
          end
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

      if blocked_sin_consolidar
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "Para jalar un paquete desde otra pre-alerta, esta debe estar en modo Consolidando."
        return
      end

      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later

      notice = if source_pa_vacia && source_pa
        "Paquete agregado. La pre-alerta #{source_pa.numero_documento} quedó vacía y fue eliminada."
      else
        "Paquete agregado a la pre-alerta."
      end

      redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: notice
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
        # `con_reempaque` lo deriva el modelo del servicio; ver `PreAlerta`.
        :tipo_envio_id, :consolidado, :notas_grupo, :titulo, :proveedor,
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

    # Move / delete rules matrix (Abril 2026):
    # - Unlinked (paquete_id nil): can move to any consolidado PA (EXP/CER/CEM) and can be
    #   deleted from the source PA. Works for any source tipo, including CKA/CKM.
    # - Linked with recibido_miami / empacado / enviado_honduras: can move to same-tipo
    #   consolidando PA; PAP can be deleted (Paquete stays in warehouse). BLOCKED for
    #   CKA/CKM sources.
    # - Linked with en_aduana or later: BLOCKED.
    # - Destino must be consolidando EXP/CER/CEM (never CKA/CKM).
    ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras].freeze

    def puede_mover?(pap)
      return false if @pre_alerta.finalizado?

      if pap.paquete_id.present?
        # Linked paquetes: cannot move from CKA/CKM, must be in movible estado
        return false if @pre_alerta.tipo_envio.single_package?
        ESTADOS_MOVIBLES.include?(pap.paquete.estado)
      else
        # Unlinked (estado PRE_ALERTA): always movable, even from CKA/CKM
        true
      end
    end

    def puede_eliminar?(pap)
      return false if @pre_alerta.finalizado?
      pap.paquete_id.nil?
    end

    def puede_editar?(pap)
      return false if @pre_alerta.finalizado?
      pap.paquete_id.nil?
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

    def agregar_placeholder(pap_id)
      # Placeholder = PAP cuyo paquete físico aún no llega. Antes (legacy)
      # eso era `paquete_id IS NULL`. Con eager-creation, además puede ser
      # un Paquete asociado en estado `pre_alerta_estado`.
      pap = PreAlertaPaquete
              .joins(:pre_alerta)
              .left_outer_joins(:paquete)
              .where(pre_alertas: { cliente_id: current_cliente.id, deleted_at: nil })
              .where.not(pre_alertas: { estado: "anulado" })
              .where.not(pre_alertas: { id: @pre_alerta.id })
              .where("pre_alerta_paquetes.paquete_id IS NULL OR paquetes.estado = 'pre_alerta_estado'")
              .find_by(id: pap_id)

      unless pap
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "Paquete no encontrado."
        return
      end

      source_pa = pap.pre_alerta

      if source_pa.tipo_envio.single_package?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "No se puede jalar un paquete de una pre-alerta CKA/CKM."
        return
      end

      unless source_pa.consolidando?
        redirect_to edit_cuenta_pre_alerta_path(@pre_alerta),
                    alert: "Solo se pueden jalar paquetes de pre-alertas consolidando."
        return
      end

      source_pa_vacia = false
      PreAlertaPaquete.transaction do
        timestamp = Time.current.strftime("%d/%m/%Y %H:%M")
        paq_desc = pap.descripcion.presence || pap.tracking

        notas_origen = source_pa.notas_grupo.presence
        notas_suffix = notas_origen ? " Notas del grupo origen: \"#{notas_origen}\"." : ""

        origen_entry  = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) jalado a #{@pre_alerta.numero_documento} — #{@pre_alerta.titulo}.#{notas_suffix}"
        destino_entry = "[#{timestamp}] Paquete '#{paq_desc}' (#{pap.tracking}) jalado de #{source_pa.numero_documento} — #{source_pa.titulo}.#{notas_suffix}"

        pap.update!(pre_alerta: @pre_alerta)
        source_pa.append_historial!(origen_entry)
        @pre_alerta.append_historial!(destino_entry)

        if source_pa.pre_alerta_paquetes.reload.empty?
          source_pa.soft_delete!
          source_pa_vacia = true
        else
          PreAlertaMailer.confirmacion(source_pa).deliver_later
        end
      end

      PreAlertaMailer.confirmacion(@pre_alerta).deliver_later

      notice = source_pa_vacia ?
        "Paquete agregado. La pre-alerta #{source_pa.numero_documento} quedó vacía y fue eliminada." :
        "Paquete agregado a la pre-alerta."

      redirect_to edit_cuenta_pre_alerta_path(@pre_alerta), notice: notice
    end

    # PAPs sin paquete físico (estado PRE_ALERTA) en otras PAs del cliente.
    # Solo se pueden jalar a un destino consolidando (matriz: mover un PAP
    # PRE_ALERTA requiere destino consolidando CER/CEM/EXP). Origen no puede
    # ser CKA/CKM ni finalizada.
    def placeholders_para_buscar
      return [] unless @pre_alerta.consolidando?

      # Placeholder = PAP esperando su paquete físico. Cubre ambos casos:
      # legacy (paquete_id NULL) y nuevo (paquete asociado en
      # pre_alerta_estado).
      PreAlertaPaquete
        .joins(pre_alerta: :tipo_envio)
        .left_outer_joins(:paquete)
        .where("pre_alerta_paquetes.paquete_id IS NULL OR paquetes.estado = 'pre_alerta_estado'")
        .where(pre_alertas: { cliente_id: current_cliente.id,
                              consolidado: true,
                              finalizado: false,
                              deleted_at: nil })
        .where.not(pre_alertas: { id: @pre_alerta.id })
        .where.not(pre_alertas: { estado: "anulado" })
        .where("tipo_envios.max_paquetes_por_accion IS NULL OR tipo_envios.max_paquetes_por_accion != 1")
        .includes(pre_alerta: :tipo_envio)
        .order("pre_alerta_paquetes.created_at DESC")
    end

    def puede_buscar?
      return false if @pre_alerta.finalizado?
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

      # Vinculados (mover entre PAs) solo si la PA destino es consolidando.
      # La matriz requiere que el destino de un move sea CONSOLIDANDO del mismo tipo.
      return sueltos.to_a.sort_by { |p| p.fecha_recibido_miami || p.created_at }.reverse unless @pre_alerta.consolidando?

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
