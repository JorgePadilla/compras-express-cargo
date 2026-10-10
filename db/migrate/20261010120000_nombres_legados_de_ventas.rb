# PR-F1.0 · Los objetos de `ventas` y `venta_items` que todavía se llaman
# `facturas*` / `factura_items*` pasan a llamarse como su tabla.
#
# Fase 15 (facturación SAR) estrena una tabla `facturas` de verdad, y Postgres
# le pondría `facturas_id_seq`, `facturas_pkey` e `index_facturas_on_*`: los
# mismos nombres que hoy ocupan las secuencias, PKs e índices de `ventas`. El
# `create_table :facturas` explotaría con «relation already exists».
#
# De dónde salieron: el dump de `db/structure.sql` del revert de PR #134
# (2026-05-05) se hizo desde una base de dev que había pasado por un rename
# `ventas → facturas → ventas` local. Ninguna migración del repo renombra esas
# tablas, así que **una base armada corriendo las migraciones** (Render) tiene
# los nombres buenos desde siempre, y **una armada desde `structure.sql`**
# (test, dev, `db:prepare` sobre una base vacía) tiene los legados. Por eso cada
# rename va con `IF EXISTS`: donde ya se llaman bien, no hace nada; donde no,
# los arregla. Las dos bases terminan iguales.
#
# Solo DDL, sin cambio de comportamiento: la secuencia sigue siendo la misma
# (el `DEFAULT nextval(...)` apunta por OID) y renombrar la PK renombra también
# su índice.
class NombresLegadosDeVentas < ActiveRecord::Migration[8.0]
  SECUENCIAS = {
    "facturas_id_seq" => "ventas_id_seq",
    "factura_items_id_seq" => "venta_items_id_seq"
  }.freeze

  # tabla => { legado => nuevo }
  PKS = {
    "ventas" => { "facturas_pkey" => "ventas_pkey" },
    "venta_items" => { "factura_items_pkey" => "venta_items_pkey" }
  }.freeze

  INDICES = {
    "index_facturas_on_cliente_id" => "index_ventas_on_cliente_id",
    "index_facturas_on_creado_por_id" => "index_ventas_on_creado_por_id",
    "index_facturas_on_estado" => "index_ventas_on_estado",
    "index_facturas_on_financiamiento_id" => "index_ventas_on_financiamiento_id",
    "index_facturas_on_numero" => "index_ventas_on_numero",
    "index_facturas_on_pre_factura_id" => "index_ventas_on_pre_factura_id",
    "index_factura_items_on_factura_id" => "index_venta_items_on_venta_id",
    "index_factura_items_on_paquete_id" => "index_venta_items_on_paquete_id"
  }.freeze

  def up
    renombrar(SECUENCIAS, INDICES, PKS)
  end

  # Vuelve a los nombres legados (los de `structure.sql` antes de esto). Sobre
  # una base de Render, que nunca los tuvo, los deja con los nombres legados
  # igual: es el estado exacto que describía el dump anterior.
  def down
    renombrar(SECUENCIAS.invert, INDICES.invert, PKS.transform_values(&:invert))
  end

  private

  def renombrar(secuencias, indices, pks)
    secuencias.each do |de, a|
      execute "ALTER SEQUENCE IF EXISTS public.#{de} RENAME TO #{a}"
    end

    # `RENAME CONSTRAINT` no tiene `IF EXISTS`: se pregunta antes.
    pks.each do |tabla, renombres|
      renombres.each do |de, a|
        execute <<~SQL
          DO $$
          BEGIN
            IF EXISTS (SELECT 1 FROM pg_constraint
                        WHERE conname = '#{de}' AND conrelid = 'public.#{tabla}'::regclass) THEN
              ALTER TABLE public.#{tabla} RENAME CONSTRAINT #{de} TO #{a};
            END IF;
          END
          $$;
        SQL
      end
    end

    indices.each do |de, a|
      execute "ALTER INDEX IF EXISTS public.#{de} RENAME TO #{a}"
    end
  end
end
