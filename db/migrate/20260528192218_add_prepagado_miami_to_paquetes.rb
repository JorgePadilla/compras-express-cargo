class AddPrepagadoMiamiToPaquetes < ActiveRecord::Migration[8.0]
  # PR-6 (Entrega Personal): cuando alguien paga al recibir el paquete en
  # Miami, NO se emite factura formal — solo se marca este flag + se
  # registra dónde, cuándo y quién lo cobró. La etiqueta muestra "PREPAGADO
  # EN MIAMI · SUCURSAL XX" y cuando llega a Honduras el sistema avisa.
  def change
    add_column    :paquetes, :prepagado_miami, :boolean, default: false, null: false
    add_reference :paquetes, :prepagado_miami_sucursal, foreign_key: { to_table: :sucursales }, null: true
    add_column    :paquetes, :prepagado_miami_at, :datetime, null: true
    add_reference :paquetes, :prepagado_miami_by_user, foreign_key: { to_table: :users }, null: true
  end
end
