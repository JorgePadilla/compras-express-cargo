# PR-D1.b: agrega `users.iniciales` editable por admin al crear/editar
# usuario. Yusef confirmó (2026-04-29) que NO se calcula del nombre porque
# hay nombres repetidos y cada usuario define su alias custom (ej. "Y.G.",
# "JP", "YS"). Se imprime en el WR y como autoría de cada cambio de fecha.
class AddInicialesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :iniciales, :string, limit: 8
  end
end
