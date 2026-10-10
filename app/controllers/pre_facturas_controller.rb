# PR-P.11b · Sin `new`/`create`: la pre-factura nace escaneando (la hoja →
# Auditar → F9/F8, `GuardarPreFacturaAuditada`). Jorge, 2026-10-10: «quitar la
# de a mano; todo por escaneo». Acá queda verla, corregirla y llevarla a
# factura. `/pre_facturas/new` redirige a la hoja (routes).
class PreFacturasController < ApplicationController
  before_action :require_feature_access
  before_action :set_pre_factura, only: %i[show edit update confirmar facturar anular etiqueta_entrega]

  def index
    @pre_facturas = PreFactura.includes(:cliente, :creado_por, :manifiesto).recientes
    @pre_facturas = apply_filters(@pre_facturas)
    @pre_facturas = @pre_facturas.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  # C30-19 · PR-P.3 · La etiqueta de entrega 4×6. Con `?print=true` imprime y
  # se cierra sola (`_etiqueta_autoprint`), como las otras etiquetas.
  #
  # La imprimen F8 y F9 al auditar, y el botón de la ficha la reimprime —
  # *"es la única etapa de todo el sistema que ellos ocupan de imprimir ese"*.
  def etiqueta_entrega
    @etiqueta = EtiquetaDeEntrega.new(@pre_factura)
    render layout: "etiqueta_entrega"
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
    # PR-P.9 · El botón no sale, pero un pedido armado a mano sí llega.
    if (motivo = @pre_factura.motivo_para_no_confirmar)
      return redirect_to edit_pre_factura_path(@pre_factura), alert: motivo
    end

    if @pre_factura.confirmar!
      redirect_to edit_pre_factura_path(@pre_factura), notice: "Pre-factura confirmada."
    else
      redirect_to edit_pre_factura_path(@pre_factura), alert: "No se pudo confirmar la pre-factura."
    end
  end

  def facturar
    if (motivo = @pre_factura.motivo_para_no_facturar)
      return redirect_to edit_pre_factura_path(@pre_factura), alert: motivo
    end

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

  def apply_filters(scope)
    scope = scope.buscar(params[:q]) if params[:q].present?
    scope = scope.where(manifiesto_id: params[:manifiesto_id]) if params[:manifiesto_id].present?
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
