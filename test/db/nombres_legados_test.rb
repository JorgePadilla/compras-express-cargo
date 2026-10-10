require "test_helper"

# PR-F1.0 · Las secuencias, PKs e índices de `ventas` y `venta_items` se llaman
# como su tabla, no `facturas*` / `factura_items*`.
#
# La Fase 15 crea una tabla `facturas` de verdad, y Postgres le daría a ella
# esos mismos nombres. Este test pregunta **por tabla** (dueña de la secuencia,
# `conrelid` de la PK, `tablename` del índice) y no «que no exista nada llamado
# `facturas*`» a propósito: cuando llegue `facturas`, sus `facturas_pkey` y
# `facturas_id_seq` son legítimos, y un test por nombre quedaría en rojo sin
# que nada esté mal.
class NombresLegadosTest < ActiveSupport::TestCase
  TABLAS = %w[ventas venta_items].freeze

  test "la secuencia del id de cada tabla lleva el nombre de la tabla" do
    TABLAS.each do |tabla|
      seq = select_value("SELECT pg_get_serial_sequence('public.#{tabla}', 'id')")
      assert_equal "public.#{tabla}_id_seq", seq
    end
  end

  test "la PK de cada tabla lleva el nombre de la tabla" do
    TABLAS.each do |tabla|
      pk = select_value(<<~SQL)
        SELECT conname FROM pg_constraint
         WHERE contype = 'p' AND conrelid = 'public.#{tabla}'::regclass
      SQL
      assert_equal "#{tabla}_pkey", pk
    end
  end

  test "ningún índice de ventas ni venta_items se llama factura*" do
    legados = connection.select_values(<<~SQL)
      SELECT indexname FROM pg_indexes
       WHERE schemaname = 'public'
         AND tablename IN ('ventas', 'venta_items')
         AND indexname LIKE '%factura%'
         AND indexname NOT LIKE '%pre_factura%'
    SQL
    assert_empty legados
  end

  test "los índices renombrados existen con su nombre nuevo" do
    esperados = %w[
      index_ventas_on_cliente_id index_ventas_on_creado_por_id index_ventas_on_estado
      index_ventas_on_financiamiento_id index_ventas_on_numero index_ventas_on_pre_factura_id
      index_venta_items_on_venta_id index_venta_items_on_paquete_id
    ]
    existentes = connection.select_values(<<~SQL)
      SELECT indexname FROM pg_indexes
       WHERE schemaname = 'public' AND tablename IN ('ventas', 'venta_items')
    SQL
    assert_empty esperados - existentes
  end

  private

  def connection = ActiveRecord::Base.connection

  def select_value(sql) = connection.select_value(sql)
end
