require "test_helper"

# C20-10: que la búsqueda de clientes pueda usar sus índices.
#
# No es un test de velocidad — es un test de que **el índice sea siquiera
# usable**, que es el invariante que se rompió sin que nadie se enterara:
# `PR-10.c` creó un GIN sobre `(nombre || ' ' || apellido)` y `PR-10.f` envolvió
# esa expresión en `translate(...)` para ignorar acentos. Postgres solo usa un
# índice de expresión cuando la expresión aparece **idéntica** en el WHERE, así
# que el índice quedó muerto: meses manteniéndolo en cada escritura sin que lo
# usara nadie, y nadie podía notarlo porque la búsqueda seguía dando los
# resultados correctos.
#
# `enable_seqscan = off` es lo que hace la pregunta contestable: en test hay
# diez clientes y el planner elegiría seq scan aunque los índices estuvieran
# perfectos. Apagándolo, si el índice **puede** usarse, aparece; si no, el plan
# se sigue yendo por otro lado y el test lo canta.
#
# `SET LOCAL`: se revierte solo con la transacción del test.
class ClienteBusquedaIndicesTest < ActiveSupport::TestCase
  # Las cuatro ramas del OR tienen que ser indexables **a la vez**: con una
  # sola que no lo sea, Postgres no puede armar el BitmapOr y evalúa las cuatro
  # fila por fila. Es exactamente por eso que el índice de código nunca sirvió.
  test "la búsqueda arma un BitmapOr con los cuatro índices" do
    plan = explicar(Cliente.buscar_flexible("2867").to_sql)

    assert_match(/BitmapOr/, plan,
                 "sin BitmapOr las cuatro ramas se evalúan fila por fila")
    %w[
      index_clientes_on_busqueda_codigo_trgm
      index_clientes_on_busqueda_nombre_trgm
      index_clientes_on_email_trgm
      index_clientes_on_codigo_digitos
    ].each do |indice|
      assert_match(/#{indice}/, plan, "la rama de #{indice} volvió a quedar sin índice")
    end
  end

  test "el nombre se busca por el índice, con acentos y sin ellos" do
    [ "Perez", "Pérez" ].each do |termino|
      assert_match(/index_clientes_on_busqueda_nombre_trgm/, explicar(Cliente.buscar(termino).to_sql),
                   "buscar «#{termino}» dejó de poder usar el índice del nombre")
    end
  end

  test "el código exacto entra por su índice" do
    assert_match(/index_clientes_on_codigo_digitos/, explicar(Cliente.buscar("2867").to_sql))
  end

  # Las columnas se calculan solas: si alguien las escribe a mano, Postgres
  # rechaza. Y sobre todo: se mantienen al día sin callbacks.
  test "las columnas se calculan al guardar y se mantienen" do
    cliente = Cliente.create!(codigo: "CEC-0042", nombre: "José", apellido: "Núñez Pérez",
                              email: "jose@example.com", activo: true)

    assert_equal "42", cliente.reload.codigo_digitos, "los ceros a la izquierda se ignoran"
    assert_equal "Jose Nunez Perez", cliente.busqueda_nombre
    assert_equal "CEC-0042", cliente.busqueda_codigo

    cliente.update!(apellido: "Ñandú")
    assert_equal "Jose Nandu", cliente.reload.busqueda_nombre, "no se actualizó sola"
  end

  private

  def explicar(sql)
    conexion = ActiveRecord::Base.connection
    conexion.execute("SET LOCAL enable_seqscan = off")
    conexion.execute("EXPLAIN #{sql}").map { |fila| fila["QUERY PLAN"] }.join("\n")
  end
end
