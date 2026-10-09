# PR-C29.9 · La «alarma» pasa a ser el sonido de error por defecto. Jorge,
# 2026-10-08: *"el audio de error creo que tiene que ser más cruel, fuerte,
# molesto, intenso"*.
#
# Solo cambia el default de la columna, para los usuarios que se creen de acá
# en adelante. **No toca a los que ya existen**: todos tienen `grave` guardado
# —la columna es NOT NULL con default—, y no hay forma de saber quién la eligió
# en el modal y quién nunca lo abrió. A ellos les llega igual lo áspero: la voz
# nueva (`SonidosDeError::VOZ`) suena en cualquier variante.
class LaAlarmaEsElErrorPorDefecto < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :sonido_error_variante, from: "grave", to: "alarma"
  end
end
