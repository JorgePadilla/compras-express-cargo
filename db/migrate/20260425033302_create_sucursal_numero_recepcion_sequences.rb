class CreateSucursalNumeroRecepcionSequences < ActiveRecord::Migration[8.0]
  def up
    # Indices para performance del listado (filtrado y busqueda).
    add_index :paquetes, :fecha_disponible unless index_exists?(:paquetes, :fecha_disponible)
    add_index :paquetes, :sucursal_id unless index_exists?(:paquetes, :sucursal_id)

    # Secuencia atomica por sucursal para numero_recepcion. Nombre:
    # `numero_recepcion_<PREFIX>_seq` (ej. numero_recepcion_RM_seq).
    # Serializable via nextval() sin locks de aplicacion. Mismo patron que
    # entregas_numero_seq / aperturas_caja_numero_seq (migracion 20260412060700).
    Sucursal.find_each do |sucursal|
      seq_name = "numero_recepcion_#{sucursal.codigo_recepcion_prefix}_seq"
      prefix = sucursal.codigo_recepcion_prefix
      execute "CREATE SEQUENCE IF NOT EXISTS #{seq_name} START WITH 1"
      # Avanza la secuencia pasando el max actual (para coexistir con data legacy)
      execute <<~SQL
        SELECT setval('#{seq_name}',
          COALESCE((
            SELECT MAX(CAST(SUBSTRING(numero_recepcion FROM #{prefix.length + 2}) AS INTEGER))
            FROM paquetes
            WHERE numero_recepcion LIKE '#{prefix}-%'
          ), 0) + 1, false)
      SQL
    end
  end

  def down
    Sucursal.find_each do |sucursal|
      seq_name = "numero_recepcion_#{sucursal.codigo_recepcion_prefix}_seq"
      execute "DROP SEQUENCE IF EXISTS #{seq_name}"
    end
    remove_index :paquetes, :fecha_disponible if index_exists?(:paquetes, :fecha_disponible)
    remove_index :paquetes, :sucursal_id if index_exists?(:paquetes, :sucursal_id)
  end
end
