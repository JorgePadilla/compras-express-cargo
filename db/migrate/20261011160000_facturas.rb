# PR-F2.2a · Fase 15. La factura SAR, dormida: el modelo y la emisión existen,
# ninguna pantalla la llama todavía (el corte es F2.4).
#
# Jorge, 2026-10-10: *modelo nuevo `Factura` que reemplaza a `Venta`*. Lo que
# hay acá es lo fiscal —número, CAI, rango, fecha límite, emisor y cliente
# congelados, totales y desglose del ISV tal como salieron de la gema—. Pagos,
# saldo y entregables llegan en F2.4.
#
# El documento completo (`Invoice#to_h`) vive en `documentos_fiscales` (#523);
# la factura cuelga de él como `documentable`. Lo de acá son las columnas por
# las que se busca, se lista y se imprime.
#
# **Lo fiscal no se edita.** Un trigger rechaza cambiar cualquiera de esas
# columnas una vez guardada, y borrar la fila: una factura emitida se corrige
# anulándola (Art. 41), y la anulación solo toca `estado` y lo que la anota.
# Las líneas, igual: no se cambian ni se borran.
class Facturas < ActiveRecord::Migration[8.0]
  CAMPOS_FISCALES = %w[
    numero punto_de_emision_id cliente_id fecha_emision cai rango_inicio rango_fin fecha_limite_emision
    cliente_nombre cliente_rtn cliente_identificacion moneda tasa_cambio
    subtotal descuento impuesto total desglose
  ].freeze

  def change
    create_table :facturas do |t|
      # `EEE-PPP-01-NNNNNNNN`.
      t.string :numero, null: false, index: { unique: true }
      t.references :punto_de_emision, null: false, foreign_key: { to_table: :puntos_de_emision }
      t.references :cliente, null: false, foreign_key: true
      t.references :creado_por, foreign_key: { to_table: :users }
      t.string :estado, null: false, default: "emitida"
      t.date :fecha_emision, null: false

      # La autorización con la que se emitió, como sale impresa (Art. 10 num. 3-5).
      t.string :cai, null: false
      t.string :rango_inicio, null: false
      t.string :rango_fin, null: false
      t.date :fecha_limite_emision, null: false

      # El comprador tal como se facturó (Art. 11): si mañana cambia el RTN
      # del cliente, esta factura no cambia.
      t.string :cliente_nombre, null: false
      t.string :cliente_rtn
      t.string :cliente_identificacion

      t.string :moneda, null: false
      t.decimal :tasa_cambio, precision: 10, scale: 4

      # Los nombres de la app (`Fiscal::Totales`): `subtotal` es el bruto.
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :descuento, precision: 12, scale: 2, null: false, default: 0
      t.decimal :impuesto, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      # Exento / exonerado / gravado 15 / 18, con su ISV (Art. 11 num. 1 lit. g-l).
      t.jsonb :desglose, null: false, default: {}

      t.datetime :anulada_at
      t.text :motivo_anulacion
      t.timestamps

      t.index :fecha_emision
      t.check_constraint "estado::text = ANY (ARRAY['emitida'::text, 'anulada'::text])", name: "facturas_estado"
      t.check_constraint "moneda::text = ANY (ARRAY['LPS'::text, 'USD'::text])", name: "facturas_moneda"
      t.check_constraint "numero::text ~ '^[0-9]{3}-[0-9]{3}-01-[0-9]{8}$'", name: "facturas_numero"
      t.check_constraint "total >= 0 AND subtotal >= 0 AND descuento >= 0 AND impuesto >= 0", name: "facturas_montos"
      t.check_constraint "(estado::text = 'anulada') = (anulada_at IS NOT NULL)", name: "facturas_anulada_con_fecha"
    end

    create_table :factura_items do |t|
      t.references :factura, null: false, foreign_key: true
      # D5 de FISCAL.md (A7-32): de qué línea de qué pre-factura salió.
      t.references :pre_factura_item, foreign_key: true
      t.references :paquete, foreign_key: true
      t.references :bulto, foreign_key: true
      t.string :concepto, null: false
      t.decimal :peso_cobrar, precision: 10, scale: 2
      t.decimal :precio_libra, precision: 10, scale: 2
      t.decimal :subtotal, precision: 12, scale: 2, null: false
      t.decimal :descuento_monto, precision: 12, scale: 2, null: false, default: 0
      t.string :tratamiento, null: false
      t.timestamps

      t.check_constraint "subtotal >= 0 AND descuento_monto >= 0", name: "factura_items_montos"
      t.check_constraint "length(btrim(concepto)) > 0", name: "factura_items_concepto"
    end

    add_reference :pre_facturas, :factura, foreign_key: true

    reversible do |dir|
      dir.up do
        distinto = CAMPOS_FISCALES.map { |c| "NEW.#{c} IS DISTINCT FROM OLD.#{c}" }.join(" OR ")
        execute <<~SQL
          CREATE FUNCTION public.facturas_fiscal_inmutable() RETURNS trigger
            LANGUAGE plpgsql AS $$
          BEGIN
            IF TG_OP = 'DELETE' THEN
              RAISE EXCEPTION 'una factura emitida no se borra: se anula (Art. 41)'
                USING ERRCODE = 'restrict_violation';
            END IF;
            IF #{distinto} THEN
              RAISE EXCEPTION 'los datos fiscales de la factura % no se cambian: se anula (Art. 41)', OLD.numero
                USING ERRCODE = 'restrict_violation';
            END IF;
            RETURN NEW;
          END
          $$;

          CREATE TRIGGER facturas_fiscal_inmutable
            BEFORE UPDATE OR DELETE ON public.facturas
            FOR EACH ROW EXECUTE FUNCTION public.facturas_fiscal_inmutable();

          CREATE FUNCTION public.factura_items_inmutables() RETURNS trigger
            LANGUAGE plpgsql AS $$
          BEGIN
            RAISE EXCEPTION 'las líneas de una factura emitida no se cambian (% rechazado)', TG_OP
              USING ERRCODE = 'restrict_violation';
          END
          $$;

          CREATE TRIGGER factura_items_inmutables
            BEFORE UPDATE OR DELETE ON public.factura_items
            FOR EACH ROW EXECUTE FUNCTION public.factura_items_inmutables();
        SQL
      end
      dir.down do
        execute "DROP FUNCTION public.facturas_fiscal_inmutable() CASCADE"
        execute "DROP FUNCTION public.factura_items_inmutables() CASCADE"
      end
    end
  end
end
