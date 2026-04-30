# PR-D1.c: paquete tiene una sucursal "actual" (donde está físicamente
# en este momento) que puede diferir de la sucursal_destino. Cuando se
# escanea/recibe en una sucursal, esto se setea. Sub-localidad es opcional
# (no todas las sucursales tienen bodegas internas configuradas todavía).
#
# Recolecta: tarifa fija $35 USD pre-establecida, editable inline por
# cajero (Yusef 2026-04-29 6:22pm). No hay tabla de tarifas todavía
# porque siempre cambia por zona/cantidad.
class AddSucursalActualYRecolectaToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :sucursal_actual,
                  foreign_key: { to_table: :sucursales }, index: true, null: true
    add_reference :paquetes, :sub_localidad_actual,
                  foreign_key: { to_table: :sub_localidades }, index: true, null: true

    add_column :paquetes, :recolecta_solicitada, :boolean, null: false, default: false
    add_column :paquetes, :recolecta_monto,     :decimal, precision: 10, scale: 2
    add_column :paquetes, :recolecta_moneda,    :string,  default: "USD"
  end
end
