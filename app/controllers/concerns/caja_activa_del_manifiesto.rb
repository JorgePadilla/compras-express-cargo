# C31-01 · La caja en la que entra lo que se escanea en la barra de la ficha.
#
# Yusef, en la prueba del 2026-10-12: *"escaneo y le pongo una caja, le pongo
# 20 libras y le doy a agregar e imprimir"* — y después escanea en la barra de
# abajo, esperando que los paquetes caigan **en esa caja**. La barra los metía
# sueltos, y todo salía «sin escanear». Y lo otro: *"queremos eliminar ese
# empacar escaneando… que sea esta barra que está abajo"*.
#
# Es **estado de un turno**, no un dato del manifiesto —igual que la caja activa
# de la vieja pantalla de empacar—: dos operarios llenando el mismo manifiesto
# llenan cada uno la suya. Vive en la sesión, por manifiesto.
#
# Por defecto, **la última caja armada**: es la que se acaba de imprimir y la que
# se está llenando. Una caja borrada no puede seguir abierta: si la guardada ya
# no existe, vuelve a la última.
module CajaActivaDelManifiesto
  extend ActiveSupport::Concern

  CLAVE = :caja_abierta_del_manifiesto

  included do
    helper_method :caja_activa_del_manifiesto
  end

  def caja_activa_del_manifiesto(manifiesto = @manifiesto)
    cajas = manifiesto.cajas.ordenadas.to_a
    return nil if cajas.empty?

    guardada = session.dig(CLAVE, manifiesto.id.to_s)
    cajas.find { |c| c.id == guardada } || cajas.last
  end

  def guardar_caja_activa(manifiesto, caja)
    session[CLAVE] = (session[CLAVE] || {}).merge(manifiesto.id.to_s => caja.id)
  end
end
