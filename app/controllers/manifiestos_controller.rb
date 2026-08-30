class ManifiestosController < ApplicationController
  # `buscar` (JSON) lo usan operadores que editan paquetes pero no
  # necesariamente tienen rol de Miami — se gatea via authorize_edit
  # del paquete antes de llegar acá.
  before_action :authorize_manifiestos, except: [ :buscar ]
  before_action :set_manifiesto, only: [ :show, :edit, :update, :add_paquete, :remove_paquete, :enviar ]

  def index
    @manifiestos = Manifiesto.activos.includes(:empresa_manifiesto).order(created_at: :desc)
    @manifiestos = @manifiestos.buscar(params[:q]) if params[:q].present?
    @manifiestos = @manifiestos.by_estado(params[:estado]) if params[:estado].present?
    @manifiestos = @manifiestos.page(params[:page]).per(per_page_sanitized)
  end

  def show
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino).order(:created_at)
  end

  def new
    @manifiesto = Manifiesto.new
    assigns_del_formulario
  end

  def create
    atributos = manifiesto_params
    @manifiesto = Manifiesto.new(atributos)
    @manifiesto.sucursal_origen_id = sucursal_origen_para(atributos)
    @manifiesto.user = Current.user

    if @manifiesto.save
      redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} creado exitosamente."
    else
      assigns_del_formulario
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    assigns_del_formulario
  end

  def update
    if @manifiesto.update(manifiesto_params)
      redirect_to @manifiesto, notice: "Manifiesto actualizado exitosamente."
    else
      assigns_del_formulario
      render :edit, status: :unprocessable_entity
    end
  end

  def add_paquete
    paquete = Paquete.find(params[:paquete_id])
    paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} agregado al manifiesto.")
  end

  def remove_paquete
    paquete = @manifiesto.paquetes.find(params[:paquete_id])
    # PR-C6.22: sacar del manifiesto devuelve a **recibido**, no a empacado.
    # Con el módulo de empaque todavía sin existir, nadie asigna `empacado`,
    # así que devolver ahí dejaba el paquete en un estado sin dueño: no lo
    # produce ninguna pantalla y no lo consume ningún flujo.
    paquete.update!(manifiesto: nil, estado: EtiquetarController::ESTADO_AL_ETIQUETAR)
    @manifiesto.recalculate_totals!
    respond_to_paquete_change("Paquete #{paquete.guia} removido del manifiesto.")
  end

  def enviar
    @manifiesto.enviar!
    redirect_to @manifiesto, notice: "Manifiesto #{@manifiesto.numero} enviado exitosamente."
  end

  # Endpoint JSON para el autocomplete del manifiesto en el form del paquete.
  def buscar
    q = params[:q].to_s.strip
    scope = Manifiesto.activos.includes(:sucursal_origen).order(created_at: :desc).limit(10)
    scope = scope.buscar(q) if q.present?
    render json: scope.map { |m|
      {
        id: m.id,
        numero: ERB::Util.html_escape(m.numero),
        estado: ERB::Util.html_escape(m.estado.to_s),
        fecha_enviado: m.fecha_enviado&.strftime("%d/%m/%Y %H:%M"),
        sucursal: ERB::Util.html_escape(m.sucursal_origen&.codigo.to_s),
        paquetes_count: m.paquetes.count
      }
    }
  end

  private def authorize_manifiestos
    require_role(:supervisor_miami, :digitador_miami)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  def respond_to_paquete_change(message)
    @paquetes = @manifiesto.paquetes.includes(:cliente, :sucursal, :sucursal_destino).order(:created_at)
    @manifiesto.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("manifiesto-paquetes", partial: "manifiestos/paquetes_table", locals: { manifiesto: @manifiesto, paquetes: @paquetes }),
          turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { notice: message })
        ]
      end
      format.html { redirect_to @manifiesto, notice: message }
    end
  end

  # C21-02 · Lo que la pantalla puede mandar. Las columnas viejas `tipo_envio`,
  # `numero_guia` y `numero_caja` **salen de acá**: dejan de escribirse y quedan
  # solo para leer lo que ya está grabado.
  def manifiesto_params
    params.require(:manifiesto).permit(
      :numero, :expedido_por, :empresa_manifiesto_id,
      # El encabezado que Yusef anotó campo por campo sobre el impreso.
      :consignatario_id, :tipo_envio_proveedor_id, :sucursal_entrega_id, :es_prioridad,
      # `sucursal_origen_id` es lo que despierta la numeración anual. Estaba
      # fuera de esta lista, y por eso `MM2026000001` no corría nunca (RP-46).
      :sucursal_origen_id,
      # La fecha en que NOSOTROS lo recibimos en Honduras. La llena SPS después.
      :fecha_aduana,
      tipo_envio_ids: [],
      guias_attributes: %i[id numero position _destroy]
    )
  end

  # C21-02 · La sucursal de origen es lo que le da número anual al manifiesto.
  # Si la pantalla no la manda, se usa la misma regla que /etiquetar y
  # /entrega_personal — vive en `Sucursal` justamente para que no se separen.
  def sucursal_origen_para(atributos)
    return atributos[:sucursal_origen_id] if atributos[:sucursal_origen_id].present?

    Sucursal.recepcion_por_defecto_para(Current.user)&.id
  end

  def assigns_del_formulario
    @empresas          = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios       = TipoEnvio.activos.order(:nombre)
    @tipos_proveedor   = TipoEnvioProveedor.activos.ordered
    @consignatarios    = Consignatario.activos.ordered
    @sucursales_origen = Sucursal.de_recepcion
    @sucursales_entrega = Sucursal.de_retiro
  end
end
