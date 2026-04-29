# PR-5c.5 parte 2: agrega FK `paquetes.warehouse_receipt_id` + backfill.
#
# Crea un `WarehouseReceipt` por cada `numero_recepcion` único existente y
# asocia cada paquete al WR correspondiente. Las N cajas de un split (que
# comparten `numero_recepcion`) quedan apuntando al mismo WR.
#
# Mantiene `paquetes.numero_recepcion` (no se elimina) por:
#   1) Retrocompatibilidad con índices existentes (búsqueda ILIKE).
#   2) Sigue siendo conveniente leer el número directo en queries simples.
#   El WR es el modelo "rico"; el string en paquetes es un duplicado leíble.
#
# `warehouse_receipt_id` se deja nullable para no romper data legacy en
# producción si la migración de datos falla por cualquier razón. La FK no
# nullable se puede agregar en un PR posterior cuando todo el flujo de
# creación pase por `WarehouseReceipt#paquetes`.
class AddWarehouseReceiptToPaquetes < ActiveRecord::Migration[8.0]
  def up
    add_reference :paquetes, :warehouse_receipt, foreign_key: true, null: true,
                  index: { name: "idx_paquetes_warehouse_receipt" }

    # Backfill: por cada numero_recepcion único, crear un WR y asociar
    # los paquetes correspondientes. Si el WR ya existe (por seed o por
    # corrida previa de la migración), reusarlo.
    say_with_time "Backfill warehouse_receipts desde paquetes existentes" do
      backfill_count = 0

      execute(<<~SQL).to_a.each do |row|
        SELECT DISTINCT numero_recepcion, sucursal_id, cliente_id,
               MIN(fecha_recibido_miami) AS issued_on,
               MIN(user_id) AS user_id
        FROM paquetes
        WHERE numero_recepcion IS NOT NULL
          AND warehouse_receipt_id IS NULL
        GROUP BY numero_recepcion, sucursal_id, cliente_id
      SQL
        receipt_number = row["numero_recepcion"]
        next if receipt_number.blank?

        wr_id = execute(
          "SELECT id FROM warehouse_receipts WHERE receipt_number = #{quote(receipt_number)} LIMIT 1"
        ).first&.dig("id")

        if wr_id.nil?
          issued_on = row["issued_on"] ? Date.parse(row["issued_on"].to_s) : Date.current
          execute(<<~SQL)
            INSERT INTO warehouse_receipts
              (receipt_number, issued_on, consignee_id, sucursal_id, user_id, status,
               declared_value_currency, total_pieces, total_weight_lb,
               total_volumetric_weight_lb, total_volume_cuft,
               declared_value_cents, consolidation,
               created_at, updated_at)
            VALUES
              (#{quote(receipt_number)}, #{quote(issued_on)}, #{quote(row['cliente_id'])},
               #{quote(row['sucursal_id'])}, #{quote(row['user_id'])}, 'received',
               'USD', 0, 0, 0, 0, 0, false, NOW(), NOW())
          SQL

          wr_id = execute(
            "SELECT id FROM warehouse_receipts WHERE receipt_number = #{quote(receipt_number)} LIMIT 1"
          ).first["id"]
        end

        execute(<<~SQL)
          UPDATE paquetes
          SET warehouse_receipt_id = #{quote(wr_id)}
          WHERE numero_recepcion = #{quote(receipt_number)}
            AND warehouse_receipt_id IS NULL
        SQL
        backfill_count += 1
      end

      say "Asignados #{backfill_count} warehouse_receipts a paquetes"
    end
  end

  def down
    remove_reference :paquetes, :warehouse_receipt, foreign_key: true,
                     index: { name: "idx_paquetes_warehouse_receipt" }
  end
end
