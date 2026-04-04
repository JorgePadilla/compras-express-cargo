class CreatePreAlertas < ActiveRecord::Migration[8.0]
  def change
    create_table :pre_alertas do |t|
      t.string :numero_documento, null: false
      t.references :cliente, null: false, foreign_key: true
      t.references :tipo_envio, null: false, foreign_key: true
      t.boolean :consolidado, default: false
      t.boolean :con_reempaque, default: false
      t.text :notas_grupo
      t.string :estado, default: "pre_alerta", null: false
      t.boolean :notificado, default: false
      t.string :creado_por_tipo
      t.bigint :creado_por_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :pre_alertas, :numero_documento, unique: true
    add_index :pre_alertas, :estado
    add_index :pre_alertas, [:creado_por_tipo, :creado_por_id]
    add_index :pre_alertas, :deleted_at
  end
end
