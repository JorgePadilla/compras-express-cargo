# PR-5c.5 parte 1: modelo WarehouseReceipt según spec
# `warehouse_receipt_fields.md`. Es el "número madre" que agrupa N paquetes
# del mismo tracking físico (split). Reemplaza/agrega al `paquetes.numero_recepcion`
# string actual.
#
# La integración con `Paquete` (FK + migración de data) se hace en parte 2
# de este PR para reducir blast radius. Este PR crea solo el modelo y su
# infraestructura básica.
class CreateWarehouseReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :warehouse_receipts do |t|
      # Identificación
      t.string :receipt_number, null: false  # mismo formato que numero_recepcion: RM0002026000001
      t.date :issued_on, null: false
      t.datetime :printed_at
      t.string :printed_by_initials

      # Asociaciones (opcionales hasta migrar paquetes en parte 2)
      t.references :supplier, foreign_key: true
      t.references :consignee, foreign_key: { to_table: :clientes }
      t.references :agent, foreign_key: true
      t.references :user, foreign_key: true
      t.references :pre_alerta, foreign_key: { to_table: :pre_alertas }
      t.references :sucursal, foreign_key: { to_table: :sucursales }

      # Campos del paquete (alineados con spec)
      t.string :service_code              # EXPRESS, CER, CEM, CKA, CKM (mismo que tipo_envio.codigo)
      t.string :repackaging_type          # sin_reempacar | reempacar | reempacar_unitario
      t.boolean :consolidation, null: false, default: false

      # Valor declarado en cents
      t.integer :declared_value_cents, null: false, default: 0
      t.string :declared_value_currency, null: false, default: "USD"

      # Totales agregados (denormalizados para PDF rápido).
      # KG y m³ se calculan via Measurement helper, no se almacenan.
      t.integer :total_pieces, null: false, default: 0
      t.decimal :total_weight_lb, precision: 10, scale: 2, default: 0
      t.decimal :total_volumetric_weight_lb, precision: 10, scale: 2, default: 0
      t.decimal :total_volume_cuft, precision: 10, scale: 2, default: 0

      # Estado del WR (lifecycle independiente del paquete)
      t.string :status, null: false, default: "draft"  # draft | received | printed | dispatched | delivered | abandoned
      t.string :terms_version            # ej. "2026-01" — congelado para auditoría

      t.text :notes_internal

      t.timestamps
    end

    add_index :warehouse_receipts, :receipt_number, unique: true,
              name: "idx_wr_receipt_number"
    add_index :warehouse_receipts, :status
    add_index :warehouse_receipts, :issued_on
  end
end
