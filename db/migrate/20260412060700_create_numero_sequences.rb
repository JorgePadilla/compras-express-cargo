class CreateNumeroSequences < ActiveRecord::Migration[8.0]
  def up
    # Atomic sequences for numero generation — eliminates race conditions
    # from the previous MAX+1 pattern. Each model gets its own sequence.
    execute "CREATE SEQUENCE entregas_numero_seq START WITH 1"
    execute "CREATE SEQUENCE aperturas_caja_numero_seq START WITH 1"
    execute "CREATE SEQUENCE ingresos_caja_numero_seq START WITH 1"
    execute "CREATE SEQUENCE egresos_caja_numero_seq START WITH 1"

    # Advance sequences past any existing records
    execute <<~SQL
      SELECT setval('entregas_numero_seq',
        COALESCE((SELECT MAX(CAST(SUBSTRING(numero FROM 4) AS INTEGER)) FROM entregas), 0) + 1, false)
    SQL
    execute <<~SQL
      SELECT setval('aperturas_caja_numero_seq',
        COALESCE((SELECT MAX(CAST(SUBSTRING(numero FROM 4) AS INTEGER)) FROM aperturas_caja), 0) + 1, false)
    SQL
    execute <<~SQL
      SELECT setval('ingresos_caja_numero_seq',
        COALESCE((SELECT MAX(CAST(SUBSTRING(numero FROM 4) AS INTEGER)) FROM ingresos_caja), 0) + 1, false)
    SQL
    execute <<~SQL
      SELECT setval('egresos_caja_numero_seq',
        COALESCE((SELECT MAX(CAST(SUBSTRING(numero FROM 4) AS INTEGER)) FROM egresos_caja), 0) + 1, false)
    SQL
  end

  def down
    execute "DROP SEQUENCE IF EXISTS entregas_numero_seq"
    execute "DROP SEQUENCE IF EXISTS aperturas_caja_numero_seq"
    execute "DROP SEQUENCE IF EXISTS ingresos_caja_numero_seq"
    execute "DROP SEQUENCE IF EXISTS egresos_caja_numero_seq"
  end
end
