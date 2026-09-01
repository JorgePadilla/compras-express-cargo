# `RP-58` paso 2a · Una persona puede tener **varios roles**.
#
# Yusef, 2026-08-30, sobre dos personas de San Pedro que el enum de un solo rol
# no sabe nombrar: Michelle es *"Sub-Jefa de área de Caja y SAC"* y Bessy
# *"Supervisora de Caja y SAC"*.
#
# `users.rol` **se queda** y sigue siendo el rol principal: es el que se muestra,
# el que alimenta los predicados del enum (`admin?`, `cajero?`) y el que decide
# el cortocircuito de admin. Esta tabla guarda los **adicionales**, que suman
# accesos y nunca los quitan.
#
# Tabla y no columna de arreglo por lo mismo que `permisos_de_rol`: el día que
# alguien pregunte quién le dio qué a quién, la respuesta tiene que existir. Con
# `paper_trail` sobre filas, existe.
class CrearRolesDeUsuario < ActiveRecord::Migration[8.0]
  def change
    create_table :roles_de_usuario do |t|
      t.references :user, null: false, foreign_key: true
      t.string :rol, null: false

      t.timestamps
    end

    # Un rol adicional no se puede repetir en la misma persona. Es la misma
    # forma que `permisos_de_rol` usa para (rol, sección).
    add_index :roles_de_usuario, %i[user_id rol], unique: true
  end
end
