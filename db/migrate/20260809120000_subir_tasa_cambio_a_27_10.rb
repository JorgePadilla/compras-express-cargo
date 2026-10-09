# PR-C6.29: mover la tasa de cambio de 24.85 a 27.10.
#
# Yusef la escribió sobre el PDF de preguntas al confirmar el mínimo de CER:
#
#     tasa 27.10
#     4.50 × 1    = 121.95  + ISV = 200      "ya con ISV"
#     4.50 × 1.5  = 182.93  + ISV = 210.36   "ya con ISV"
#
# Con la 24.85 que había, esa segunda línea no reproduce: 6.75 × 24.85 =
# L.167.76, que queda por debajo del mínimo neto (173.91) y el paquete
# terminaba cobrando L.200 en vez de L.210.37.
#
# Va como migración de datos y no solo en el seed porque el seed usa
# `find_or_create_by!`: no pisa una `Configuracion` que ya existe, así que
# re-sembrar staging la habría dejado en 24.85 para siempre.
#
# Solo mueve el valor si sigue siendo el viejo. Si alguien ya la ajustó a mano
# desde la pantalla nueva, esa decisión gana — no la queremos revertir con un
# deploy.
class SubirTasaCambioA2710 < ActiveRecord::Migration[8.0]
  ANTERIOR = "24.85".freeze
  NUEVA    = "27.10".freeze

  def up
    actualizar(desde: ANTERIOR, hasta: NUEVA)
  end

  def down
    actualizar(desde: NUEVA, hasta: ANTERIOR)
  end

  private

  def actualizar(desde:, hasta:)
    # El nombre sale del modelo: la tabla es `configuracions` (sin inflexión
    # en español) y escribirlo a mano acá se rompería el día que se agregue.
    tabla = Configuracion.table_name
    fila = execute("SELECT id, valor FROM #{tabla} WHERE clave = 'tasa_cambio' LIMIT 1").first
    return say("no hay tasa_cambio cargada, no se toca nada") if fila.nil?

    if fila["valor"].to_d != BigDecimal(desde)
      return say("tasa_cambio esta en #{fila['valor']}, no en #{desde}: se respeta lo configurado")
    end

    execute("UPDATE #{tabla} SET valor = '#{hasta}', updated_at = NOW() WHERE id = #{fila['id'].to_i}")
    say("tasa_cambio: #{desde} -> #{hasta}")
  end
end
