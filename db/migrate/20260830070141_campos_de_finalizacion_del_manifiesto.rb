# C21-06 · Quién finalizó el manifiesto y cuándo.
#
# *"Cuando termino el manifiesto se bloquea… se bloquea para que nadie lo
# [toque]. Sí es editable, **pero tiene el botón de editar**."*
class CamposDeFinalizacionDelManifiesto < ActiveRecord::Migration[8.0]
  def change
    change_table :manifiestos, bulk: true do |t|
      t.references :finalizado_por, foreign_key: { to_table: :users }
      t.datetime :finalizado_at
    end
  end
end
