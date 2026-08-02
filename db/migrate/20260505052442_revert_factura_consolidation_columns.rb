# Revierte la migración 20260505025649 (PR #134 — Factura schema prep).
#
# Jorge confirmó 2026-05-05 que PreFactura se mantiene como modelo y que el
# flujo es siempre PreFactura → Factura (conversión), no dos modelos
# paralelos. Las columnas que PR #134 agregó preparaban para una consolidación
# de Venta+PreFactura en una sola tabla `facturas`, plan que fue cancelado.
# Las columnas quedaron como dead weight sin código que las use.
#
# Revierte:
#   - ventas: fecha_trabajo, confirmado_at, facturado_at
#   - venta_items: origen, tarifa_recolecta_id, servicio_extra_id
#   - paquetes, notas_debito, notas_credito, pagos, recibos, cotizaciones,
#     financiamientos: factura_id (FK paralelo a venta_id)
class RevertFacturaConsolidationColumns < ActiveRecord::Migration[8.0]
  def up
    remove_reference :financiamientos, :factura, foreign_key: { to_table: :ventas } if column_exists?(:financiamientos, :factura_id)
    remove_reference :cotizaciones,    :factura, foreign_key: { to_table: :ventas } if column_exists?(:cotizaciones, :factura_id)
    remove_reference :recibos,         :factura, foreign_key: { to_table: :ventas } if column_exists?(:recibos, :factura_id)
    remove_reference :pagos,           :factura, foreign_key: { to_table: :ventas } if column_exists?(:pagos, :factura_id)
    remove_reference :notas_credito,   :factura, foreign_key: { to_table: :ventas } if column_exists?(:notas_credito, :factura_id)
    remove_reference :notas_debito,    :factura, foreign_key: { to_table: :ventas } if column_exists?(:notas_debito, :factura_id)
    remove_reference :paquetes,        :factura, foreign_key: { to_table: :ventas } if column_exists?(:paquetes, :factura_id)

    remove_reference :venta_items, :servicio_extra,   foreign_key: true if column_exists?(:venta_items, :servicio_extra_id)
    remove_reference :venta_items, :tarifa_recolecta, foreign_key: true if column_exists?(:venta_items, :tarifa_recolecta_id)
    if column_exists?(:venta_items, :origen)
      remove_index  :venta_items, :origen if index_exists?(:venta_items, :origen)
      remove_column :venta_items, :origen
    end

    remove_column :ventas, :facturado_at,  :datetime if column_exists?(:ventas, :facturado_at)
    remove_column :ventas, :confirmado_at, :datetime if column_exists?(:ventas, :confirmado_at)
    remove_column :ventas, :fecha_trabajo, :date     if column_exists?(:ventas, :fecha_trabajo)
  end

  def down
    add_column :ventas, :fecha_trabajo,  :date
    add_column :ventas, :confirmado_at,  :datetime
    add_column :ventas, :facturado_at,   :datetime

    add_column :venta_items, :origen, :string, default: "manual", null: false
    add_index  :venta_items, :origen
    add_reference :venta_items, :tarifa_recolecta, foreign_key: { on_delete: :nullify }, null: true
    add_reference :venta_items, :servicio_extra,   foreign_key: { on_delete: :nullify }, null: true

    add_reference :paquetes,        :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :notas_debito,    :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :notas_credito,   :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :pagos,           :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :recibos,         :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :cotizaciones,    :factura, foreign_key: { to_table: :ventas }, null: true
    add_reference :financiamientos, :factura, foreign_key: { to_table: :ventas }, null: true
  end
end
