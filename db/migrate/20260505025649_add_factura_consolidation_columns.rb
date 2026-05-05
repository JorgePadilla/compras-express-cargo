# PR-FAC.1 (Factura consolidation, PR 1/4): preparación de schema.
#
# Yusef pidió consolidar `Venta` + `PreFactura` en un solo modelo `Factura`.
# Esta migración es **non-breaking**: solo agrega columnas paralelas sin
# borrar nada legacy. PR-2 hará el rename de tablas y PR-3 migrará datos.
#
# Cambios:
#   - ventas:        + fecha_trabajo, confirmado_at, facturado_at
#   - venta_items:   + origen, tarifa_recolecta_id, servicio_extra_id
#   - paquetes:      + factura_id (paralelo a venta_id/pre_factura_id)
#   - notas_debito:  + factura_id (paralelo a venta_id)
#   - notas_credito: + factura_id (paralelo a venta_id)
#   - pagos:         + factura_id (paralelo a venta_id)
#   - recibos:       + factura_id (paralelo a venta_id)
#   - cotizaciones:  + factura_id (paralelo a venta_id)
#   - financiamientos: + factura_id (paralelo a venta_id)
class AddFacturaConsolidationColumns < ActiveRecord::Migration[8.0]
  def change
    # ventas: campos de timeline para cubrir borrador/confirmado
    add_column :ventas, :fecha_trabajo,  :date     unless column_exists?(:ventas, :fecha_trabajo)
    add_column :ventas, :confirmado_at,  :datetime unless column_exists?(:ventas, :confirmado_at)
    add_column :ventas, :facturado_at,   :datetime unless column_exists?(:ventas, :facturado_at)

    # venta_items: origen + audit FKs (paralelo a pre_factura_items)
    unless column_exists?(:venta_items, :origen)
      add_column :venta_items, :origen, :string, default: "manual", null: false
      add_index  :venta_items, :origen
    end
    add_reference :venta_items, :tarifa_recolecta, foreign_key: { on_delete: :nullify }, null: true unless column_exists?(:venta_items, :tarifa_recolecta_id)
    add_reference :venta_items, :servicio_extra,   foreign_key: { on_delete: :nullify }, null: true unless column_exists?(:venta_items, :servicio_extra_id)

    # paquetes y modelos hijos: factura_id paralelo
    add_reference :paquetes,        :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:paquetes, :factura_id)
    add_reference :notas_debito,    :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:notas_debito, :factura_id)
    add_reference :notas_credito,   :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:notas_credito, :factura_id)
    add_reference :pagos,           :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:pagos, :factura_id)
    add_reference :recibos,         :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:recibos, :factura_id)
    add_reference :cotizaciones,    :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:cotizaciones, :factura_id)
    add_reference :financiamientos, :factura, foreign_key: { to_table: :ventas }, null: true unless column_exists?(:financiamientos, :factura_id)

    # Backfill: venta_items legacy con origen NULL → "manual"
    reversible do |dir|
      dir.up { execute "UPDATE venta_items SET origen = 'manual' WHERE origen IS NULL" }
    end
  end
end
