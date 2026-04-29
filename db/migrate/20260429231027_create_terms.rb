# PR-5c.5 parte 1: modelo Terms (T&C) versionado según spec WR §9.
# Cada WR congela una `terms_version` para auditoría. Las T&C son texto
# bilingüe (en/es) editable por admin sin redeploy.
class CreateTerms < ActiveRecord::Migration[8.0]
  def change
    create_table :terms do |t|
      t.string :version, null: false        # ej. "2026-01"
      t.string :language, null: false       # "es" | "en"
      t.text :body, null: false
      t.date :effective_from, null: false
      t.boolean :activo, null: false, default: true
      t.timestamps
    end

    add_index :terms, [ :version, :language ], unique: true,
              name: "idx_terms_version_language"
    add_index :terms, :activo
  end
end
