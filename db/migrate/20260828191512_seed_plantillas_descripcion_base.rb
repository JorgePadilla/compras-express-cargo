# C19-04, seguimiento: la seed de las dos plantillas de descripción viaja en
# la migración, para que staging las tenga sin pasos a mano.
#
# `PR-C7.58` las dejó solo en `db/seeds.rb`, y el deploy de Render **solo
# migra, nunca siembra** — el catálogo iba a nacer vacío hasta que alguien
# corriera `db:seed`, que es exactamente la trampa que ya pasó con los
# motivos de envío por política (`C18-06`). Jorge, 2026-08-28: "pon la seed
# en la migración para que se corra".
#
# En SQL y no con el modelo, para no depender de cómo esté el modelo el día
# que corra. Idempotente por título: si la fila ya existe (sembrada, o creada
# por el equipo de Yusef desde /plantillas_descripcion), no se toca — el
# catálogo es de ellos. El down borra solo estas dos, por si hay que volver.
class SeedPlantillasDescripcionBase < ActiveRecord::Migration[8.0]
  PLANTILLAS = [
    [ "Sellado",      "Sellado",      0 ],
    [ "Compra chino", "Compra chino", 1 ]
  ].freeze

  def up
    PLANTILLAS.each do |titulo, texto, position|
      existe = execute("SELECT 1 FROM plantillas_descripcion WHERE titulo = '#{titulo}' LIMIT 1").first
      if existe
        say("'#{titulo}' ya existe, no se toca")
        next
      end

      execute(<<~SQL)
        INSERT INTO plantillas_descripcion (titulo, texto, activo, position, created_at, updated_at)
        VALUES ('#{titulo}', '#{texto}', TRUE, #{position}, NOW(), NOW())
      SQL
      say("'#{titulo}' sembrada")
    end
  end

  def down
    PLANTILLAS.each do |titulo, _texto, _position|
      execute("DELETE FROM plantillas_descripcion WHERE titulo = '#{titulo}'")
    end
  end
end
