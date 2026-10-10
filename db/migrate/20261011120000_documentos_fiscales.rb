# PR-F1.2 · Fase 15. Dónde guarda la gema `invoicehn` los documentos emitidos.
#
# El contrato del store (`Invoicehn::TestSupport::StoreContract`) pide cuatro
# cosas que ninguna tabla de hoy da:
#
# - `save_document` → `find` / `exists?` por número, de vuelta igual;
# - `delete_document` que **borra de verdad**: la gema lo llama cuando el libro
#   rechaza el asiento, para que no quede un documento sin su número contado;
# - la forma ANULADA reemplaza a la emitida (Art. 41), el número queda;
# - y `find(referencia)` de una nota tiene que encontrar la factura, sea de la
#   tabla que sea.
#
# `asientos_fiscales` no sirve —es solo para agregar— y `facturas` todavía no
# existe (F2.2a). Así que el documento fiscal tiene su tabla, una para los tres
# tipos, y el registro de negocio (la Factura de F2.2a, una nota) cuelga de él
# por `documentable`. El `documento` es `Invoice#to_h`, que es lo que la gema
# vuelve a leer.
#
# De paso, `asientos_fiscales.documento` deja de ser obligatorio: el contrato
# del libro registra un documento que nunca pasó por el store, y lo que el
# asiento referencia ahora es esta tabla, que existe solo si se guardó.
class DocumentosFiscales < ActiveRecord::Migration[8.0]
  def change
    create_table :documentos_fiscales do |t|
      # `EEE-PPP-TT-NNNNNNNN`, el número completo.
      t.string :numero, null: false, index: { unique: true }
      t.references :punto_de_emision, null: false, foreign_key: { to_table: :puntos_de_emision }
      t.column :tipo_documento, "char(2)", null: false
      t.date :fecha_emision, null: false
      t.string :estado, null: false
      t.string :cai, null: false
      t.jsonb :documento, null: false
      # La Factura (F2.2a) o la nota que lo originó. Opcional: el store
      # funciona sin ella, y los tests de contrato no tienen ninguna.
      t.references :documentable, polymorphic: true, index: { unique: true }
      t.timestamps

      t.index :fecha_emision
      t.check_constraint "tipo_documento IN ('01', '06', '07')", name: "documentos_fiscales_tipo_documento"
      t.check_constraint "estado::text = ANY (ARRAY['emitida'::text, 'anulada'::text])",
                         name: "documentos_fiscales_estado"
    end

    change_column_null :asientos_fiscales, :documento_type, true
    change_column_null :asientos_fiscales, :documento_id, true
  end
end
