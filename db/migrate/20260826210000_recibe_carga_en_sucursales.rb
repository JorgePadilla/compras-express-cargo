# Qué sucursales reciben carga.
#
# Yusef, 2026-08-26, viendo el chooser de /etiquetar ofrecerle San Pedro,
# Tegucigalpa y San Manuel: *"aquí te falta Miami… ¿dónde se está recibiendo
# el paquete? No es a dónde va. Debería ser las sucursales donde recibimos
# carga, no donde entregamos carga. En este momento solo es Miami; futuramente
# Los Ángeles, Panamá, México"* (`C18-02`).
#
# No existía el concepto: el chooser filtraba por la ubicación del usuario, y
# `ubicacion` (miami/honduras/otros) no alcanza —México sería `otros` y ningún
# usuario es `otros`—. Es un checkbox en `/sucursales`, como
# `retiro_por_defecto`: México la crea y la marca él. Backfill en SQL y no con
# el modelo, para no depender de cómo esté el modelo el día que corra.
class RecibeCargaEnSucursales < ActiveRecord::Migration[8.0]
  def up
    add_column :sucursales, :recibe_carga, :boolean, null: false, default: false
    execute "UPDATE sucursales SET recibe_carga = TRUE WHERE ubicacion = 'miami'"
  end

  def down
    remove_column :sucursales, :recibe_carga
  end
end
