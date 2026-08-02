# PR-D3.a: catálogo estructurado de Proveedores.
# Yusef 2026-04-30: "debernos crear un listado de proveedores pero estos
# deben ser como una busqueda como cuando buscar clientes, y debemos
# tener una lista para los mismos. ya que muchos son recurrentes…"
#
# Reemplaza la columna `paquetes.proveedor` (string libre) por
# `paquetes.proveedor_id` (FK al catálogo). La columna `proveedor`
# original queda como fallback nullable durante la transición y para
# mostrar valores históricos hasta que se haga el backfill.
class CreateProveedoresYProveedorIdEnPaquetes < ActiveRecord::Migration[8.0]
  def change
    create_table :proveedores do |t|
      t.string  :nombre,  null: false
      t.string  :codigo,  null: false, limit: 8 # holgura para manejar colisiones (AMZ2, AMZ3...)
      t.string  :tipo,    null: false, default: "comercio" # comercio | entrega_personal
      t.integer :position, null: false, default: 0
      t.boolean :activo,  null: false, default: true
      t.text    :notas
      t.timestamps
    end

    add_index :proveedores, :nombre, unique: true
    add_index :proveedores, :codigo, unique: true
    add_index :proveedores, :activo
    add_index :proveedores, :tipo

    add_reference :paquetes, :proveedor,
                  null: true,
                  foreign_key: { on_delete: :restrict }
  end
end
