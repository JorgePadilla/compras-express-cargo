# PR-D6.b: trackear origen de cada línea de pre-factura.
# Yusef confirmó (2026-05-01) que los cargos por recolecta y cambio
# de servicio se agregan automáticamente cuando el paquete entra a
# la pre-factura. Necesitamos distinguir esas líneas auto de las
# líneas manuales para:
#   - Re-generarlas idempotentemente si la pre-factura cambia.
#   - Mostrar en UI con tag "Auto" para que el cajero sepa que vino
#     del paquete (y pueda editar para descuentos autorizados).
#   - Reportes financieros que separen revenue por categoría.
class AddOrigenToPreFacturaItems < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_factura_items, :origen, :string,
               null: false, default: "manual"
    add_index  :pre_factura_items, :origen

    # FKs opcionales para auditar de qué entrada del catálogo vino
    # cada línea auto. Permite editar el catálogo sin perder trazabilidad.
    add_reference :pre_factura_items, :tarifa_recolecta,
                  null: true, foreign_key: { to_table: :tarifas_recolecta, on_delete: :nullify }
    add_reference :pre_factura_items, :servicio_extra,
                  null: true, foreign_key: { to_table: :servicios_extra, on_delete: :nullify }
  end
end
