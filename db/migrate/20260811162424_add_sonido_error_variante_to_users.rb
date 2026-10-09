# RP-20: cuál de las tres opciones del sonido de error usa cada quien.
#
# El default es `grave`, que es el sonido que ya suena hoy: nadie escucha nada
# distinto hasta que lo elija. Cuando Yusef decida, se cambia el default acá y
# ahí sí cambia para todos.
class AddSonidoErrorVarianteToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sonido_error_variante, :string, null: false, default: "grave"
  end
end
