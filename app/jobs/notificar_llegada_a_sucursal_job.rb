# A7-08 · La ventana: *"con el manifiesto notifique, pero darle una ventana de
# media hora, por ejemplo, o una hora"*. Se programa con el primer paquete
# escaneado del interno y corre `NotificarLlegadaASucursal`, que avisa a los
# clientes cuyos paquetes llegaron y todavía no fueron avisados. Si para
# entonces ya cerraron la recepción, no encuentra a quién avisar y no hace nada.
class NotificarLlegadaASucursalJob < ApplicationJob
  queue_as :default

  def perform(manifiesto)
    # C34-08 · Si quien recibe puso una hora que todavía no llega, la ventana
    # no se adelanta: avisa el barrido, a esa hora.
    return unless NotificarLlegadaASucursal.hora_de_avisar?(manifiesto.reload)

    NotificarLlegadaASucursal.new(manifiesto).call
  end
end
