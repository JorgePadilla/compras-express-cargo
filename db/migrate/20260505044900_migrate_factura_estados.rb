# PR-FAC.3b: migra estados legacy a nuevo enum unificado.
# pendiente→emitido, pagada→pagado, anulada→anulado.
# proforma queda igual (PR-3d migrará a Cotizacion).
class MigrateFacturaEstados < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE facturas SET estado = 'emitido' WHERE estado = 'pendiente'"
    execute "UPDATE facturas SET estado = 'pagado'  WHERE estado = 'pagada'"
    execute "UPDATE facturas SET estado = 'anulado' WHERE estado = 'anulada'"
    change_column_default :facturas, :estado, from: "pendiente", to: "borrador"
  end

  def down
    change_column_default :facturas, :estado, from: "borrador", to: "pendiente"
    execute "UPDATE facturas SET estado = 'pendiente' WHERE estado = 'emitido'"
    execute "UPDATE facturas SET estado = 'pagada'    WHERE estado = 'pagado'"
    execute "UPDATE facturas SET estado = 'anulada'   WHERE estado = 'anulado'"
  end
end
