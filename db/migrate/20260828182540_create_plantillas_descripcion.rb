class CreatePlantillasDescripcion < ActiveRecord::Migration[8.0]
  # C19-04. Yusef: "si aquí en la descripción del contenido les podemos poner
  # un check nada más que diga sellado… hay dos cosas: sellado y compra chino,
  # son más comunes". Catálogo CRUD y no botones fijos — su filosofía: "entre
  # más cosas nos dejés crear, menos te molestaremos".
  def change
    create_table :plantillas_descripcion do |t|
      t.string :titulo, null: false
      t.text :texto, null: false
      t.boolean :activo, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :plantillas_descripcion, :activo
  end
end
