# PR-D6.a follow-up: FK opcional al catálogo de tarifas de recolecta.
# Cuando el cajero elige una tarifa, el sistema autocompleta
# `paquete.recolecta_monto` y `recolecta_moneda` desde el catálogo y
# guarda la referencia para auditoría / pre-factura automática (PR-D6.b).
class AddTarifaRecolectaToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :tarifa_recolecta,
                  foreign_key: { to_table: :tarifas_recolecta, on_delete: :nullify },
                  null: true
  end
end
