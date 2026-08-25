require "test_helper"

# Un solo archivo de esquema, y que sea el que Rails de verdad usa.
#
# El repo corre con `config.active_record.schema_format = :sql`, así que la
# verdad vive en `db/structure.sql`. `db/schema.rb` igual seguía versionado y se
# había quedado pinneado en **abril de 2026**: su tabla `clientes` no tenía
# `rtn`, `acceso_habilitado`, `tema`, `sucursal_retiro_id`, `notas_caja` ni
# `notas_sac`. Rails no lo consulta con este formato, así que lo único que podía
# hacer era mentirle a quien lo leyera —o armar una base rota si alguien corría
# `db:schema:load`—.
#
# Va como lint porque el archivo vuelve solo: basta un `db:schema:dump` suelto,
# o cambiar el formato sin querer, para que reaparezca viejo desde el día uno.
class UnSoloEsquemaTest < ActiveSupport::TestCase
  test "el formato sigue siendo sql" do
    assert_equal :sql, ActiveRecord.schema_format,
                 "si esto cambia, structure.sql deja de ser la verdad y este lint hay que repensarlo"
  end

  test "db/schema.rb no vuelve" do
    schema = Rails.root.join("db/schema.rb")

    assert_not schema.exist?, <<~MSG
      Volvió `db/schema.rb`, y con `schema_format = :sql` Rails ni lo lee.

      Borralo (`rm db/schema.rb`). La verdad está en `db/structure.sql`.
    MSG
  end

  test "structure.sql sigue ahi y al dia" do
    structure = Rails.root.join("db/structure.sql").read

    assert_match(/CREATE TABLE public\.clientes/, structure)
    # Un par de columnas recientes, para que un structure.sql congelado se note.
    %w[rtn acceso_habilitado clave_actualizada_at].each do |columna|
      assert_match(/^\s+#{columna} /, structure, "#{columna} no está en structure.sql")
    end
  end
end
