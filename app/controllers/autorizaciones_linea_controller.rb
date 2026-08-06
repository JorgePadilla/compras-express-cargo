# PR-13.d: el endpoint donde el supervisor pone su PIN y el cambio se aplica.
#
# No hay un "desbloquear y después editar": llega el cambio y el PIN juntos, y
# `AutorizacionLinea.aplicar!` hace las dos cosas en una transacción o ninguna.
class AutorizacionesLineaController < ApplicationController
  before_action :require_feature_access
  before_action :set_item

  # Un PIN de 4 dígitos son 10 000 combinaciones — se agotan a fuerza bruta en
  # minutos. Es el único punto del sistema donde cuatro números mueven plata.
  #
  # El límite va **por supervisor y no por IP**, que es el default de Rails: en
  # un mostrador todos comparten la IP, así que por IP el primero en equivocarse
  # dejaría afuera a los demás y el cajero legítimo se comería el bloqueo.
  rate_limit to: 5, within: 5.minutes,
             by: -> { params.dig(:autorizacion, :autorizado_por_id).to_s },
             with: -> { rechazar("Demasiados intentos con ese PIN. Espera unos minutos.") },
             only: :create

  def create
    @autorizacion = AutorizacionLinea.aplicar!(
      item: @item,
      solicitado_por: Current.user,
      attrs: autorizacion_params
    )

    if @autorizacion.persisted?
      redirect_to edit_pre_factura_path(@pre_factura),
                  notice: "Cambio autorizado por #{@autorizacion.autorizado_por.nombre}."
    else
      # El mensaje se mantiene genérico a propósito: no decirle a quien prueba
      # si falló el PIN o el rol.
      rechazar(@autorizacion.errors.full_messages.to_sentence)
    end
  end

  private

  def require_feature_access
    redirect_to(root_path, alert: "No tienes permiso para acceder a esta seccion.") unless can_access?(:pre_facturas)
  end

  def set_item
    @pre_factura = PreFactura.find(params[:pre_factura_id])
    @item = @pre_factura.pre_factura_items.find(params[:item_id])
  end

  def rechazar(mensaje)
    redirect_to edit_pre_factura_path(params[:pre_factura_id]), alert: mensaje
  end

  def autorizacion_params
    params.require(:autorizacion)
          .permit(:accion, :valor, :modo, :autorizado_por_id, :pin, :motivo)
  end
end
