# PR-D0 (Yusef spec, 2026-04-28): el `numero_recepcion` es un "número madre"
# compartido por las N cajas de un tracking dividido (Warehouse Receipt único).
# Las cajas se distinguen por `numero_caja` (1, 2, 3, …).
#
# Esto invalida la unicidad simple sobre `numero_recepcion` que asignaba PR-C.
# Reemplazamos por una unicidad compuesta `(numero_recepcion, numero_caja)`.
class ChangeNumeroRecepcionUniqueIndexCompound < ActiveRecord::Migration[8.0]
  def change
    # Drop el índice unique simple.
    remove_index :paquetes, :numero_recepcion, unique: true,
                 name: "index_paquetes_on_numero_recepcion", if_exists: true

    # Re-crea índice no-unique para búsquedas (LIKE, sort, joins).
    add_index :paquetes, :numero_recepcion,
              name: "index_paquetes_on_numero_recepcion",
              if_not_exists: true

    # Unique compuesto: el madre + numero_caja garantiza que cada caja del
    # split sea única. Paquetes single (no split) tienen numero_caja=1 o nil
    # → el unique sigue funcionando para esos casos.
    add_index :paquetes, [ :numero_recepcion, :numero_caja ],
              unique: true,
              name: "index_paquetes_on_numero_recepcion_caja",
              if_not_exists: true
  end
end
