# C26-17 · Sacar un paquete de la lista de pendientes de medición.
#
# Jorge, mirando el panel: *"el admin debería poder quitarlos con algunas
# opciones de **perdido**, **ya fue entregado**, y una nota si es necesario,
# pero eso solo el admin"*.
#
# El estado del paquete **no se toca**: un «entregado» sin entrega registrada le
# mentiría al módulo de entregas y a la factura. Lo que se sella es que esa caja
# ya no se espera en la estación, con su motivo, para que la lista de lo que
# falta diga la verdad.
class DescartarDeMedicion < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :medicion_descartada_at, :datetime
    add_column :paquetes, :medicion_descartada_por, :string
    add_column :paquetes, :medicion_descartada_motivo, :string
    add_column :paquetes, :medicion_descartada_nota, :text
  end
end
