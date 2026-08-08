# PR-C6.14: el tercero como texto libre, que no toca la base de clientes.
#
# Yusef, 2026-08-08, sobre quién digita en Miami:
#
#   > "Solo se guarda en esa guía... queda guardado en ese warehouse receipt,
#   >  pero **no queda grabado en ninguna base de datos de clientes**."
#
# Dos razones que dio, y las dos son de autoridad, no de UI:
#
#   1. "El que está digitando ahí no tiene ni voz ni voto para guardar."
#   2. "Ellos se pueden equivocar y pueden hacer este relajo."
#
# Hoy `tercero_id` solo se asigna eligiendo un `Cliente` que ya existe. No se
# crean clientes fantasma —eso está bien— pero el texto libre que él pidió no
# existía, así que a un tercero que no está en la cartera no se le podía poner
# el nombre en la etiqueta.
class AgregarTerceroNombreAPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :tercero_nombre, :string
  end
end
