# PR-D2: motivos de retención (Yusef 2026-04-29 6:42pm):
# "ES OBLIGATORIO Y TAMBIEN ME GUSTARIA UNA PLANTILLA DE SELECCION
#  MULTIPLE"
#
# Modelo `MotivoRetencion`: catálogo simple gestionado por admin.
# Join `paquete_motivos_retencion`: un paquete puede tener múltiples
# motivos seleccionados. Cuando paquete pasa a estado=retenido, debe
# tener al menos 1 motivo o `notas_retencion` con detalle libre.
class CreateMotivosRetencionYJoin < ActiveRecord::Migration[8.0]
  def change
    create_table :motivos_retencion do |t|
      t.string :nombre,      null: false
      t.text   :descripcion
      t.integer :position,   null: false, default: 0
      t.boolean :activo,     null: false, default: true
      t.timestamps
    end

    add_index :motivos_retencion, :nombre, unique: true
    add_index :motivos_retencion, :activo

    create_table :paquete_motivos_retencion do |t|
      t.references :paquete, null: false,
                   foreign_key: { on_delete: :cascade }
      t.references :motivo_retencion, null: false,
                   foreign_key: { to_table: :motivos_retencion, on_delete: :restrict }
      t.timestamps
    end

    add_index :paquete_motivos_retencion, [ :paquete_id, :motivo_retencion_id ], unique: true,
              name: "idx_paquete_motivos_retencion_pair"
  end
end
