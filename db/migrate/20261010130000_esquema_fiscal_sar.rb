# PR-F1.1 · Fase 15: el esquema de la facturación SAR, sin la gema todavía.
#
# Jorge, 2026-10-10: *un punto de emisión por sucursal que factura*, y los CAI
# se cargan por pantalla (F1.3) porque todavía no hay CAI real. Cuatro tablas:
#
# - `puntos_de_emision`: el `EEE-PPP` del número de factura (Acuerdo 481-2017,
#   Art. 10 num. 7 a-b). Uno por sucursal, y la pareja no se repite.
# - `autorizaciones_sar`: el CAI con su rango y su fecha límite, por punto y
#   tipo de documento (Art. 59). Dos rangos del mismo punto y tipo no se pisan:
#   lo garantiza un `EXCLUDE` sobre `int8range`, que necesita `btree_gist` para
#   el `=` de las otras dos columnas. El modelo lo valida también, por si algún
#   día una base no deja crear la extensión.
# - `correlativos_fiscales`: el último número emitido por punto y tipo. Lo
#   bloquea `FOR UPDATE` quien emite (F1.2), en la misma transacción que guarda
#   el documento: así no quedan huecos.
# - `asientos_fiscales`: el libro de emisiones y anulaciones (Art. 53 num. 1 y
#   5). **Solo se agrega**: un trigger rechaza UPDATE y DELETE. No es
#   paper_trail porque paper_trail se puede borrar y esto no (D2 de FISCAL.md).
#   Las columnas son las llaves de `Invoicehn::Ledger::JsonlLedger`, en español.
class EsquemaFiscalSar < ActiveRecord::Migration[8.0]
  TIPOS = "tipo_documento IN ('01', '06', '07')".freeze

  def change
    enable_extension "btree_gist"

    create_table :puntos_de_emision do |t|
      t.references :sucursal, null: false, foreign_key: true, index: { unique: true }
      t.column :establecimiento, "char(3)", null: false
      t.column :punto, "char(3)", null: false
      t.boolean :activo, null: false, default: true
      t.timestamps

      t.index %i[establecimiento punto], unique: true
      t.check_constraint "establecimiento ~ '^[0-9]{3}$'", name: "puntos_de_emision_establecimiento_tres_digitos"
      t.check_constraint "punto ~ '^[0-9]{3}$'", name: "puntos_de_emision_punto_tres_digitos"
    end

    create_table :autorizaciones_sar do |t|
      # Sin índice propio: lo cubre el único de abajo, que arranca por el punto.
      t.references :punto_de_emision, null: false, index: false,
                                      foreign_key: { to_table: :puntos_de_emision }
      t.column :tipo_documento, "char(2)", null: false
      t.string :cai, null: false
      t.bigint :rango_inicio, null: false
      t.bigint :rango_fin, null: false
      t.date :fecha_limite_emision, null: false
      t.date :fecha_autorizacion
      # El CAI inventado de staging (F1.5). El modelo no la deja existir en
      # producción, y el PDF le pone marca de agua (F2.2b).
      t.boolean :ficticia, null: false, default: false
      t.references :cargada_por, foreign_key: { to_table: :users }
      t.timestamps

      t.index %i[punto_de_emision_id tipo_documento cai rango_inicio], unique: true,
              name: "index_autorizaciones_sar_unicas"
      t.check_constraint TIPOS, name: "autorizaciones_sar_tipo_documento"
      t.check_constraint "rango_inicio >= 1 AND rango_inicio <= rango_fin AND rango_fin <= 99999999",
                         name: "autorizaciones_sar_rango"
      t.exclusion_constraint "punto_de_emision_id WITH =, tipo_documento WITH =, " \
                             "int8range(rango_inicio, rango_fin, '[]') WITH &&",
                             using: :gist, name: "autorizaciones_sar_sin_solapar"
    end

    create_table :correlativos_fiscales do |t|
      t.references :punto_de_emision, null: false, index: false,
                                      foreign_key: { to_table: :puntos_de_emision }
      t.column :tipo_documento, "char(2)", null: false
      t.bigint :ultimo, null: false, default: 0
      t.timestamps

      t.index %i[punto_de_emision_id tipo_documento], unique: true,
              name: "index_correlativos_fiscales_unicos"
      t.check_constraint TIPOS, name: "correlativos_fiscales_tipo_documento"
      t.check_constraint "ultimo >= 0 AND ultimo <= 99999999", name: "correlativos_fiscales_ultimo"
    end

    # Sin `timestamps`: el asiento no se actualiza nunca, y `registrado_at` lo
    # pone la base.
    create_table :asientos_fiscales do |t|
      t.string :evento, null: false
      t.column :tipo_documento, "char(2)", null: false
      # El número completo `EEE-PPP-TT-NNNNNNNN`; ya lleva punto y tipo.
      t.string :numero, null: false
      t.references :punto_de_emision, null: false, foreign_key: { to_table: :puntos_de_emision }
      t.references :documento, polymorphic: true, null: false
      # El número del documento al que se refiere una nota de crédito o débito.
      t.string :referencia
      t.date :fecha_emision, null: false
      t.string :cai, null: false
      t.string :cliente_nombre
      t.string :cliente_rtn
      t.string :moneda, null: false
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :descuento, precision: 12, scale: 2, null: false, default: 0
      t.decimal :isv, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.string :estado, null: false
      t.jsonb :payload, null: false, default: {}
      t.references :usuario, foreign_key: { to_table: :users }
      t.datetime :registrado_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      # Un número se emite una vez y se anula a lo sumo una vez. Sirve además
      # de índice por número.
      t.index %i[numero evento], unique: true
      t.index :fecha_emision
      # Con `::text` explícito: el `IN` sobre un varchar se guarda con casts que
      # `pg_dump` reescribe distinto cada vez que se recarga `structure.sql`.
      t.check_constraint "evento::text = ANY (ARRAY['emision'::text, 'anulacion'::text])",
                         name: "asientos_fiscales_evento"
      t.check_constraint TIPOS, name: "asientos_fiscales_tipo_documento"
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE FUNCTION public.asientos_fiscales_solo_agregar() RETURNS trigger
            LANGUAGE plpgsql AS $$
          BEGIN
            RAISE EXCEPTION 'asientos_fiscales solo admite INSERT (% rechazado)', TG_OP
              USING ERRCODE = 'restrict_violation';
          END
          $$;

          CREATE TRIGGER asientos_fiscales_solo_agregar
            BEFORE UPDATE OR DELETE ON public.asientos_fiscales
            FOR EACH ROW EXECUTE FUNCTION public.asientos_fiscales_solo_agregar();
        SQL
      end
      # El trigger cae con la tabla (el `create_table` se deshace después).
      dir.down { execute "DROP FUNCTION public.asientos_fiscales_solo_agregar() CASCADE" }
    end
  end
end
