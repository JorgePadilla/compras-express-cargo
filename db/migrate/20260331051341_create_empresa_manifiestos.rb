class CreateEmpresaManifiestos < ActiveRecord::Migration[8.0]
  def change
    create_table :empresa_manifiestos do |t|
      t.string :nombre, null: false
      t.boolean :activo, default: true

      t.timestamps
    end
  end
end
