# Borra todos los registros legacy con estado="proforma" en `ventas`.
# Yusef confirmó 2026-05-05 que el flujo es PreFactura → Factura y que
# `proforma` desaparece como concepto. Staging es BD de prueba; sin
# necesidad de migrar a Cotizacion. Libera paquetes reservados antes de
# borrar para no dejarlos huérfanos.
class DeleteProformaVentas < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE paquetes
      SET venta_id = NULL, estado = 'disponible_entrega'
      WHERE venta_id IN (SELECT id FROM ventas WHERE estado = 'proforma')
        AND estado = 'pre_facturado';
    SQL
    execute "DELETE FROM venta_items WHERE venta_id IN (SELECT id FROM ventas WHERE estado = 'proforma')"
    execute "DELETE FROM ventas WHERE estado = 'proforma'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Los proformas borrados no se pueden recuperar"
  end
end
