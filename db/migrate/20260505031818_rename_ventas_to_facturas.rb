# PR-FAC.2 (Factura consolidation, PR 2/4): rename mecánico de tablas.
#
# Rename ventas → facturas y venta_items → factura_items. Backfill
# `factura_id` en tablas hijas desde `venta_id` para que la FK paralela
# (agregada en PR-1) quede activa apuntando a la tabla renombrada.
#
# Esta migración NO cambia el enum de estado ni la lógica de la app.
# Eso lo hace PR-3 (con migración de datos: proforma→Cotizacion,
# pendiente→emitido, etc.).
class RenameVentasToFacturas < ActiveRecord::Migration[8.0]
  def up
    # 1. Rename tables
    rename_table :ventas,       :facturas       if table_exists?(:ventas)       && !table_exists?(:facturas)
    rename_table :venta_items,  :factura_items  if table_exists?(:venta_items)  && !table_exists?(:factura_items)

    # 2. Rename FK column en factura_items
    if column_exists?(:factura_items, :venta_id) && !column_exists?(:factura_items, :factura_id)
      rename_column :factura_items, :venta_id, :factura_id
    end

    # 3. Backfill: copiar venta_id → factura_id en cada tabla hija
    %i[paquetes notas_debito notas_credito pagos recibos cotizaciones financiamientos].each do |t|
      if column_exists?(t, :venta_id) && column_exists?(t, :factura_id)
        execute "UPDATE #{t} SET factura_id = venta_id WHERE venta_id IS NOT NULL AND factura_id IS NULL"
      end
    end
  end

  def down
    # Reverse: tablas
    rename_table :facturas,       :ventas       if table_exists?(:facturas)      && !table_exists?(:ventas)
    rename_table :factura_items,  :venta_items  if table_exists?(:factura_items) && !table_exists?(:venta_items)

    # Reverse: columna
    if column_exists?(:venta_items, :factura_id) && !column_exists?(:venta_items, :venta_id)
      rename_column :venta_items, :factura_id, :venta_id
    end

    # No revertimos backfill — en down las columnas factura_id quedan pobladas pero
    # ya no apuntan a tabla renombrada. Para revertir limpio: drop column factura_id
    # desde la migración previa (PR-1) primero.
  end
end
