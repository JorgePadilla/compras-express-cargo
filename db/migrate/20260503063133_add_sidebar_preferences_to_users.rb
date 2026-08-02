# Yusef pidió que el sidebar arranque colapsado y se expanda al hover,
# con toggle de posición (left/right) y opción de pin. Las 3 preferencias
# persisten por usuario.
class AddSidebarPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sidebar_collapsed, :boolean, null: false, default: true
    add_column :users, :sidebar_pinned,    :boolean, null: false, default: false
    add_column :users, :sidebar_position,  :string,  null: false, default: "left"
  end
end
