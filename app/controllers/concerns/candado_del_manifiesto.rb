# C30-06 · El candado del manifiesto finalizado, en el servidor.
#
# Hasta acá el candado de C21-06 cuidaba **solo el encabezado** (`update`). Lo
# de adentro —agregar y sacar paquetes, armar y corregir cajas, empacar— lo
# cuidaba la vista, que no dibujaba esas secciones si el manifiesto no estaba
# `creado`. O sea, un pedido armado a mano o una pestaña vieja abierta metía o
# sacaba paquetes de un manifiesto que ya había viajado. Es lo que Yusef contó
# que les pasaba con el sistema viejo: *"ya nos pasó que venían y sin querer
# tocaban el manifiesto que ya se había ido"*.
#
# Una sola regla (`Manifiesto#modificable_por?`) para las tres pantallas que
# escriben: la ficha, las cajas y el empaque. Los escaneos contestan JSON con
# `resultado: "bloqueado"` —la pistola tiene que sonar y decir por qué—, y lo
# demás vuelve a la ficha con el aviso.
module CandadoDelManifiesto
  extend ActiveSupport::Concern

  private

  def exigir_modificable
    return if @manifiesto.modificable_por?(Current.user)

    mensaje = motivo_del_candado
    respond_to do |format|
      format.json { render json: { resultado: "bloqueado", ok: false, mensaje: mensaje }, status: :forbidden }
      # Una pestaña vieja que actúa sobre un manifiesto que se acaba de cerrar.
      # Antes se le anteponía el aviso arriba de todo —invisible si estaba
      # bajando por la tabla— y los controles viejos (la «×», la pistola) se
      # quedaban como si nada. Ahora la página se **refresca**: la ficha
      # vuelve dibujada como está de verdad (bloqueada, sin «×»), y el aviso
      # va en el flash de esa visita, arriba, con el scroll arriba.
      #
      # `request_id: nil` a propósito: por defecto turbo-rails le pone el id
      # de este pedido, y Turbo **ignora** un refresh que viene del pedido que
      # hizo la misma página (es para no refrescar dos veces con los
      # broadcasts). Acá es justamente esa página la que tiene que refrescar.
      format.turbo_stream do
        flash[:alert] = mensaje
        render turbo_stream: turbo_stream.refresh(request_id: nil), status: :forbidden
      end
      format.html { redirect_to manifiesto_path(@manifiesto), alert: mensaje }
    end
  end

  # El texto vive en el modelo (`Manifiesto#motivo_del_candado`): /paquetes
  # también lo dice cuando alguien intenta mover un paquete de uno cerrado.
  def motivo_del_candado = @manifiesto.motivo_del_candado
end
