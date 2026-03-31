class CreateClientes < ActiveRecord::Migration[8.0]
  def change
    create_table :clientes do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :apellido
      t.string :identidad
      t.string :email
      t.string :telefono
      t.string :telefono_whatsapp
      t.text :direccion
      t.string :ciudad
      t.string :departamento
      t.decimal :saldo_pendiente, precision: 10, scale: 2, default: 0
      t.references :categoria_precio, foreign_key: true
      t.boolean :correo_enviado, default: false
      t.boolean :correo_confirmado, default: false
      t.boolean :activo, default: true

      t.timestamps
    end

    add_index :clientes, :codigo, unique: true
    add_index :clientes, :email
    add_index :clientes, :activo
  end
end
