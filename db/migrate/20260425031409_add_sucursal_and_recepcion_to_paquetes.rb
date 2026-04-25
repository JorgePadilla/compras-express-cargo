class AddSucursalAndRecepcionToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :sucursal, foreign_key: true
    add_column :paquetes, :numero_recepcion, :string
    add_column :paquetes, :fecha_disponible, :datetime

    add_index :paquetes, :numero_recepcion, unique: true
  end
end
