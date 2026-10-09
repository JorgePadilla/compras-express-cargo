# Seguimiento de C18-02 (Jorge, 2026-08-27): *"Miami es el default pero podría
# ser DF México, ¿tenemos cómo ingresarlo?"*.
#
# Ingresarla ya se podía (C18-02 dejó el checkbox «acá se recibe carga»). Lo que
# no había era una regla para el default que no fuera el orden por nombre: con
# dos sucursales de recepción y un usuario de Honduras —el admin de Yusef—,
# «DF México» ordenaba antes que «Miami» y le robaba el default. Yusef: *"ahí
# vamos a amarrar al usuario de dónde es"*.
#
# Dos cosas: la sucursal donde trabaja cada usuario (opcional), y cuál sucursal
# de recepción es la de por defecto cuando el usuario no tiene una — gemelo de
# `retiro_por_defecto`. Miami queda marcada con los datos, no a mano.
#
# De paso, `codigo_recepcion_prefix` deja de ser obligatorio: desde RP-17 el
# número sale de `Sucursal#codigo` y el prefijo no lo usa nadie; crear DF México
# no puede exigir inventarle uno.
class SucursalPorUsuarioYRecepcionPorDefecto < ActiveRecord::Migration[8.0]
  def up
    add_reference :users, :sucursal, null: true, foreign_key: { to_table: :sucursales }
    add_column :sucursales, :recepcion_por_defecto, :boolean, default: false, null: false
    execute "UPDATE sucursales SET recepcion_por_defecto = TRUE WHERE ubicacion = 'miami' AND recibe_carga"
    change_column_null :sucursales, :codigo_recepcion_prefix, true

    nombre = select_value("SELECT nombre FROM sucursales WHERE recepcion_por_defecto LIMIT 1")
    say nombre ? "recepción por defecto: #{nombre}" : "ninguna sucursal recibe carga: /etiquetar queda sin default"
  end

  def down
    change_column_null :sucursales, :codigo_recepcion_prefix, false
    remove_column :sucursales, :recepcion_por_defecto
    remove_reference :users, :sucursal, foreign_key: { to_table: :sucursales }
  end
end
