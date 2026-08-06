class PreFacturasController < ApplicationController
  before_action :require_feature_access
  before_action :set_pre_factura, only: %i[show edit update confirmar facturar anular]

  def index
    @pre_facturas = PreFactura.includes(:cliente, :creado_por).recientes
    @pre_facturas = apply_filters(@pre_facturas)
    @pre_facturas = @pre_facturas.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    @pre_factura = PreFactura.new
    if params[:cliente_id].present?
      @cliente = Cliente.find(params[:cliente_id])
      @paquetes_facturables = @cliente.paquetes
        .facturables
        .includes(:tipo_envio, :sucursal, :proveedor)
        .order(:created_at)
      @cotizaciones = cotizar(@cliente, @paquetes_facturables)
    end
  end

  def create
    cliente = Cliente.find(params[:cliente_id])
    paquete_ids = Array(params[:paquete_ids]).map(&:to_i).reject(&:zero?)

    if paquete_ids.empty?
      redirect_to new_pre_factura_path(cliente_id: cliente.id),
                  alert: "Selecciona al menos un paquete."
      return
    end

    @pre_factura = PreFactura.build_from_paquetes(cliente, paquete_ids, user: Current.user)
    @pre_factura.notas = params.dig(:pre_factura, :notas)
    prepagados = @pre_factura.prepagados_miami_detected

    if @pre_factura.save
      # PR-6b: si alguno de los paquetes seleccionados venía prepagado
      # desde Miami, avisamos al cajero. La línea simbólica ya está
      # construida; aquí solo flag-eamos visualmente.
      notice = "Pre-factura #{@pre_factura.numero} creada."
      if prepagados.any?
        trackings = prepagados.map(&:tracking).join(", ")
        notice += " #{prepagados.size} paquete(s) prepagado(s) en Miami detectado(s) (#{trackings}) — agregué cobro simbólico de $#{PreFactura::PREPAGADO_MIAMI_SIMBOLICO} c/u. Ajustá el monto si necesitas antes de facturar."
      end
      redirect_to edit_pre_factura_path(@pre_factura), notice: notice
    else
      @cliente = cliente
      @paquetes_facturables = cliente.paquetes.facturables.includes(:tipo_envio)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    cargar_autorizaciones
  end

  def update
    if @pre_factura.update(pre_factura_params)
      redirect_to edit_pre_factura_path(@pre_factura), notice: "Pre-factura actualizada."
    else
      cargar_autorizaciones
      render :edit, status: :unprocessable_entity
    end
  end

  def confirmar
    if @pre_factura.confirmar!
      redirect_to edit_pre_factura_path(@pre_factura), notice: "Pre-factura confirmada."
    else
      redirect_to edit_pre_factura_path(@pre_factura), alert: "No se pudo confirmar la pre-factura."
    end
  end

  def facturar
    venta = @pre_factura.facturar!
    if venta
      nd = @pre_factura.nota_debito_auto
      notice =
        if nd
          "Venta #{venta.numero} generada. Se creo #{nd.numero} en estado CREADO - revisala antes de emitir."
        else
          "Venta #{venta.numero} generada."
        end
      redirect_to venta_path(venta), notice: notice
    else
      redirect_to edit_pre_factura_path(@pre_factura), alert: "No se pudo facturar la pre-factura."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_pre_factura_path(@pre_factura), alert: "Error al facturar: #{e.message}"
  end

  def anular
    if @pre_factura.anular!
      redirect_to pre_facturas_path, notice: "Pre-factura anulada."
    else
      redirect_to edit_pre_factura_path(@pre_factura),
                  alert: "No se puede anular una pre-factura ya facturada."
    end
  end

  def facturables
    cliente = Cliente.find(params[:cliente_id])
    paquetes = cliente.paquetes.facturables.includes(:tipo_envio, :sucursal, :proveedor)
    cotizaciones = cotizar(cliente, paquetes)

    render json: paquetes.map { |p|
      c = cotizaciones[p.id]
      {
        id: p.id,
        guia: ERB::Util.html_escape(p.guia),
        tracking: ERB::Util.html_escape(p.tracking),
        tipo_envio: ERB::Util.html_escape(p.tipo_envio&.nombre.to_s),
        peso_cobrar: p.peso_cobrar.to_f,
        precio_libra: c.precio_libra.to_f,
        subtotal: c.subtotal.to_f,
        moneda: c.moneda,
        aplico_minimo: c.aplico_minimo
      }
    }
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:pre_facturas)
  end

  def set_pre_factura
    @pre_factura = PreFactura.find(params[:id])
  end

  # PR-13.d: qué líneas llevan un cambio autorizado, para marcarlas.
  def cargar_autorizaciones
    @autorizaciones_por_item = @pre_factura.autorizaciones
                                           .includes(:autorizado_por)
                                           .order(:created_at)
                                           .group_by(&:pre_factura_item_id)
    @autorizaciones_por_item.default = []
  end

  # PR-10.h: lo que se le va a cobrar a cada paquete, indexado por id.
  #
  # Antes esta pantalla y el JSON calculaban el precio con la cadena vieja
  # (`categoria_precio.precio_para || tipo_envio.precio_libra`): sin mínimos,
  # sin escalones y sin convertir a Lempiras — pero rotulado "L.". Es el mismo
  # bug de moneda que PR-10.a arregló en `build_from_paquetes`, en el camino que
  # quedó afuera. Con los precios reales cargados la diferencia dejó de ser
  # cosmética: un CER de 0.5 lb mostraba $2.25 y la pre-factura cobraba L.173.91.
  #
  # Yusef: "queremos que el área de los precios estén establecidos, listo". Mal
  # puede estar preestablecido si la pantalla dice un número y el sistema cobra
  # otro.
  #
  # `CotizadorFlete` es el mismo servicio que usa /entrega_personal, y hay un
  # test que verifica que su resultado coincida con el de la pre-factura.
  def cotizar(cliente, paquetes)
    paquetes.index_by(&:id).transform_values do |p|
      CotizadorFlete.call(
        tipo_envio: p.tipo_envio,
        cliente: cliente,
        proveedor: p.proveedor,
        sucursal: p.sucursal,
        # `peso_cobrar` ya es el mayor entre el real y el volumétrico, así que
        # no se le pasan las medidas: recalcularlas daría lo mismo.
        peso: p.peso_cobrar
      )
    end
  end

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.by_estado(params[:estado]) if params[:estado].present?
    scope = scope.by_cliente(params[:cliente_id]) if params[:cliente_id].present?
    if params[:fecha_desde].present? && (fecha_desde = Date.parse(params[:fecha_desde]) rescue nil)
      scope = scope.where(fecha_trabajo: fecha_desde..)
    end
    if params[:fecha_hasta].present? && (fecha_hasta = Date.parse(params[:fecha_hasta]) rescue nil)
      scope = scope.where(fecha_trabajo: ..fecha_hasta)
    end
    scope
  end

  # PR-13.d: **el candado**. Yusef: "queremos que el área de los precios estén
  # establecidos, listo. No hay nada más, no se puede hacer más si está todo
  # preestablecido."
  #
  # `precio_libra`, `peso_cobrar`, `subtotal`, `descuento_monto` y `_destroy`
  # salieron de acá: los cinco cambian lo que se le cobra al cliente y ahora van
  # por `AutorizacionesLineaController`, que pide el PIN de un supervisor y deja
  # registro de quién autorizó qué y contra qué valor.
  #
  # Aplica **a todos, incluido el admin**. Si el admin puede editar suelto, el
  # registro tiene un agujero y deja de servir como prueba.
  #
  # `concepto` se queda editable: es la descripción de la línea, no el monto.
  def pre_factura_params
    params.require(:pre_factura).permit(
      :notas, :fecha_trabajo,
      pre_factura_items_attributes: [ :id, :concepto ]
    )
  end
end
