# PR-D1.d: formato anual `MM2026000001` para manifiestos, análogo al
# `numero_recepcion` (PR-A). Yusef confirmó (2026-04-29):
#   "M=manifest, M=miami, 2026=Año, 000001=numero de manifiesto
#    QUEDANDO ASI MM2026000001"
#
# Estructura del numero:
#   M<sucursal_codigo_primera_letra><año 4-dig><contador 6-dig>
# Ejemplos:
#   MM2026000001  → Manifiesto Miami 2026 #1
#   MS2026000042  → Manifiesto SPS    2026 #42
#   MT2026000001  → Manifiesto Humuya 2026 #1
#
# El contador reinicia el 1 de enero, por sucursal de origen.
# Manifiestos legacy (formato `MA-XXXXXX`) quedan como están — el nuevo
# formato aplica solo a partir del 1er manifiesto creado tras la
# migración.
class CreateManifiestoCountersAndAddSucursal < ActiveRecord::Migration[8.0]
  def change
    create_table :manifiesto_counters do |t|
      t.references :sucursal, null: false, foreign_key: { to_table: :sucursales }
      t.integer :anio, null: false
      t.integer :ultimo_numero, null: false, default: 0
      t.timestamps
    end

    add_index :manifiesto_counters, [ :sucursal_id, :anio ], unique: true,
              name: "idx_manifiesto_counters_sucursal_anio"

    # FK al manifiesto: identifica de qué sucursal sale (Miami, SPS, etc.)
    # nullable porque manifiestos legacy no tienen este dato.
    add_reference :manifiestos, :sucursal_origen,
                  foreign_key: { to_table: :sucursales }, null: true
  end
end
