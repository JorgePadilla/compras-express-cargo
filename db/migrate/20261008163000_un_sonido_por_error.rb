# C29-08 · *"Si el tipo de envío es el error, tiene que tirar un sonido de una
# forma. Si la sucursal es el error, tiene que tirar un sonido de error, pero de
# otro tono… cada error tiene que tener un tono distinto para que ellos sepan."*
#
# Una columna por error, como `sonido_error_variante`: cada operario elige con
# qué opción de `SonidosDeError::VARIANTES` suena cada uno. Los defaults son
# distintos entre sí y distintos del error de siempre (`grave`), así que sin
# tocar nada ya suenan tres cosas diferentes.
class UnSonidoPorError < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sonido_error_tipo, :string, null: false, default: "triple"
    add_column :users, :sonido_error_sucursal, :string, null: false, default: "agudo"
  end
end
