# PR-10.c (review): `Cliente.buscar` compara el código ignorando los ceros a
# la izquierda con `ltrim(regexp_replace(codigo, '\D', '', 'g'), '0')`. Esa
# expresión no es sargable, así que sin índice hace seq scan de `clientes` en
# cada tecla del autocomplete (debounce de 300ms, pero igual).
#
# Ambas funciones son IMMUTABLE, así que se puede indexar la expresión tal
# cual y PostgreSQL la usa cuando aparece idéntica en el WHERE.
class AddCodigoNormalizadoIndexAClientes < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE INDEX index_clientes_on_codigo_normalizado
          ON clientes ((ltrim(regexp_replace(codigo, '\\D', '', 'g'), '0')))
    SQL

    # El otro lado de la búsqueda son los ILIKE sobre nombre completo. pg_trgm
    # los vuelve indexables; si la extensión no está disponible en el entorno,
    # se sigue sin ella (la búsqueda funciona igual, solo más lenta).
    begin
      enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
      execute <<~SQL
        CREATE INDEX index_clientes_on_nombre_completo_trgm
            ON clientes USING gin ((nombre || ' ' || COALESCE(apellido, '')) gin_trgm_ops)
      SQL
    rescue StandardError => e
      say "pg_trgm no disponible, se omite el índice de nombre: #{e.message}"
    end
  end

  def down
    execute "DROP INDEX IF EXISTS index_clientes_on_nombre_completo_trgm"
    execute "DROP INDEX IF EXISTS index_clientes_on_codigo_normalizado"
  end
end
