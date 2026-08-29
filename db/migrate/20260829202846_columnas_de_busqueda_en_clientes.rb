# C20-10: la búsqueda de clientes deja de recalcular lo mismo 9.000 veces por
# tecla.
#
# Jorge: *"el dropdown tarda mucho"*. Una mitad era el debounce (PR-C7.77); la
# otra es esto. Cada tecla que pasaba el debounce hacía que **cada una** de las
# filas de `clientes` pagara dos `translate()` y un `regexp_replace()` en el
# filtro, y otra `regexp_replace()` más en la clave de ordenamiento.
#
# **Por qué no alcanzaba con índices.** Ya había dos (`PR-10.c`), y no servían:
#
#   · el de `codigo_normalizado` es usable, pero vive adentro de un `OR` de
#     cuatro ramas — y si una sola rama no es indexable, Postgres las evalúa
#     las cuatro fila por fila. Son las cuatro o ninguna.
#   · el GIN de `nombre_completo` está **muerto desde PR-10.f**: ese PR envolvió
#     el nombre en `translate(...)` para ignorar acentos, y un índice de
#     expresión solo se usa cuando la expresión aparece idéntica en el WHERE.
#     Meses manteniéndolo en cada escritura sin que lo usara nadie.
#
# Y para el caso real de Miami —*"solo poníamos el seis o el dos y ya con eso
# cae"*— `pg_trgm` **no puede** ayudar: con uno o dos caracteres no hay
# trigramas que indexar. O sea que la palanca no es la selectividad: es el
# costo por fila. Por eso columnas calculadas al guardar y no más índices sobre
# expresiones.
class ColumnasDeBusquedaEnClientes < ActiveRecord::Migration[8.0]
  # Las mismas expresiones que el modelo usaba inline. Las tres funciones son
  # IMMUTABLE, que es lo que Postgres exige para una columna generada.
  DIGITOS = "ltrim(regexp_replace((codigo)::text, '\\D', '', 'g'), '0')".freeze
  # Ojo con el largo: origen y destino tienen que tener los MISMOS caracteres.
  # Tenía 14 y 13, y `translate` corría el mapeo — ver `Cliente.sin_acentos`.
  ACENTOS = "'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN'".freeze

  def up
    execute <<~SQL
      ALTER TABLE clientes
        ADD COLUMN codigo_digitos   text GENERATED ALWAYS AS (#{DIGITOS}) STORED,
        ADD COLUMN busqueda_codigo  text GENERATED ALWAYS AS (translate((codigo)::text, #{ACENTOS})) STORED,
        ADD COLUMN busqueda_nombre  text GENERATED ALWAYS AS (
          translate(((nombre)::text || ' ' || (COALESCE(apellido, ''))::text), #{ACENTOS})
        ) STORED
    SQL

    # El de expresión se muda a la columna: mismo contenido, y ahora sí lo puede
    # usar la consulta que de verdad se corre.
    remove_index :clientes, name: "index_clientes_on_codigo_normalizado"
    add_index :clientes, :codigo_digitos

    # Las tres GIN o ninguna: con una sola rama indexable no hay BitmapOr
    # posible y volvemos al filtro fila por fila.
    remove_index :clientes, name: "index_clientes_on_nombre_completo_trgm"
    execute <<~SQL
      CREATE INDEX index_clientes_on_busqueda_nombre_trgm ON clientes USING gin (busqueda_nombre gin_trgm_ops);
      CREATE INDEX index_clientes_on_busqueda_codigo_trgm ON clientes USING gin (busqueda_codigo gin_trgm_ops);
      CREATE INDEX index_clientes_on_email_trgm           ON clientes USING gin ((email::text) gin_trgm_ops);
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_clientes_on_busqueda_nombre_trgm;
      DROP INDEX IF EXISTS index_clientes_on_busqueda_codigo_trgm;
      DROP INDEX IF EXISTS index_clientes_on_email_trgm;
    SQL
    remove_index :clientes, :codigo_digitos

    execute <<~SQL
      ALTER TABLE clientes
        DROP COLUMN codigo_digitos,
        DROP COLUMN busqueda_codigo,
        DROP COLUMN busqueda_nombre
    SQL

    execute <<~SQL
      CREATE INDEX index_clientes_on_codigo_normalizado ON clientes USING btree (#{DIGITOS});
      CREATE INDEX index_clientes_on_nombre_completo_trgm ON clientes
        USING gin ((((nombre)::text || ' '::text) || (COALESCE(apellido, ''::character varying))::text) gin_trgm_ops);
    SQL
  end
end
