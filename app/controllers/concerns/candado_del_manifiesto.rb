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
      format.turbo_stream do
        render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash",
                                                                    locals: { alert: mensaje }),
               status: :forbidden
      end
      format.html { redirect_to manifiesto_path(@manifiesto), alert: mensaje }
    end
  end

  def motivo_del_candado
    if !@manifiesto.reabrible?
      "#{@manifiesto.numero} ya no se puede cambiar: está #{@manifiesto.estado.humanize.downcase}."
    elsif @manifiesto.edicion_abierta?
      "#{@manifiesto.numero} está abierto para corregir, pero solo un supervisor de Miami puede cambiarlo."
    else
      "#{@manifiesto.numero} está finalizado y bloqueado: para corregirlo, un supervisor de Miami aprieta «Editar»."
    end
  end
end
