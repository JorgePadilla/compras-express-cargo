# Los correos **de notificación** de un cliente.
#
# El caso real que mostró Yusef: una clienta con dos correos a la que no le
# pueden crear cuenta, porque el correo es la llave.
#
# `clientes.email` se queda como **el de acceso** —es el que usa
# `authenticate_by`— y los demás viven acá, solo para notificar. Elegir cuál es
# el de acceso es intercambiarlos, no una segunda fuente de verdad.
class CreateClienteCorreos < ActiveRecord::Migration[8.0]
  def change
    create_table :cliente_correos do |t|
      t.references :cliente, null: false, foreign_key: true
      t.string :correo, null: false
      t.timestamps
    end

    add_index :cliente_correos, [ :cliente_id, :correo ], unique: true
  end
end
