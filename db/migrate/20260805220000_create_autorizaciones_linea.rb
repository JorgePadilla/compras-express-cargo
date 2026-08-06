# PR-13.d: el registro de cada cambio que un supervisor autorizó sobre una línea
# de pre-factura.
#
# Yusef: "no hay nada más, no se puede hacer más si está todo preestablecido.
# Ahora, si lo quieren modificar, ellos tienen que pedir autorización — ahí es
# donde entra un jefe, un supervisor, y ahí es donde llega y pone un código
# especial de él".
#
# El alcance es **por línea**, no por pre-factura: el PIN no abre un modo de
# edición, autoriza un cambio concreto y queda pegado a él.
#
# `pre_factura_id` va aparte de `pre_factura_item_id` porque una de las acciones
# es justamente eliminar la línea: el item desaparece y el registro tiene que
# sobrevivir. Por eso también se guarda el `concepto` de la línea.
#
# `valor_anterior` importa tanto como el nuevo: la tarifa se puede mover después,
# y sin el valor contra el que se autorizó la auditoría no reconstruye nada.
class CreateAutorizacionesLinea < ActiveRecord::Migration[8.0]
  def change
    create_table :autorizaciones_linea do |t|
      t.references :pre_factura, null: false, foreign_key: true
      # nullify: si se elimina la línea, el registro de que se eliminó se queda.
      t.references :pre_factura_item, foreign_key: { on_delete: :nullify }

      t.references :autorizado_por, null: false,
                   foreign_key: { to_table: :users }
      t.references :solicitado_por, null: false,
                   foreign_key: { to_table: :users }

      t.string  :accion,  null: false   # precio · peso · descuento · eliminar
      t.string  :concepto, null: false  # snapshot: la línea puede desaparecer
      t.decimal :valor_anterior, precision: 10, scale: 2
      t.decimal :valor_nuevo,    precision: 10, scale: 2
      t.string  :detalle                # "10% sobre L.1,118.30"
      t.text    :motivo, null: false

      t.timestamps
    end

    add_index :autorizaciones_linea, :created_at
    add_index :autorizaciones_linea, :accion
  end
end
