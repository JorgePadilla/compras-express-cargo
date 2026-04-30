# PR-D2: plantillas de notas al cliente (Yusef 2026-04-29):
# Catálogo compartido entre Etiquetar / Pre-Factura / Caja / SAC.
# El usuario clickea "Insertar plantilla" → dropdown → texto se inserta
# en el campo `paquetes.notas_al_cliente` (no reemplaza, append).
class CreatePlantillasNotasCliente < ActiveRecord::Migration[8.0]
  def change
    create_table :plantillas_notas_cliente do |t|
      t.string :titulo,  null: false
      t.text   :texto,   null: false
      t.integer :position, null: false, default: 0
      t.boolean :activo, null: false, default: true
      t.timestamps
    end

    add_index :plantillas_notas_cliente, :activo
  end
end
