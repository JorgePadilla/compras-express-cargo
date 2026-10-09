# C25-07 · El nombre del cliente en su fila; el tercero al renglón de recepción.
#
# Yusef, mirando la Dymo: *"Sofía García… Jorge Alejandro Federico. El nombre
# tiene que ir a una sola fila y vamos a mover el tercero para la de abajo."*
#
# El `DEFAULT` ya cambió, pero **una plantilla guardada no lo lee**:
# `Definicion#filas` toma `@def["filas"]` primero, y `agregar_faltantes` solo
# inserta campos ausentes — nunca re-parte una fila que ya existe. Así que en un
# ambiente con plantilla guardada el nombre seguiría cortándose.
#
# Idempotente: si `f-cliente` todavía trae `tercero`, lo saca y lo pone al final
# de `f-recepcion` (el único renglón con lugar — ver `definicion.rb`); si ya
# está partida, no toca nada. Y respeta el orden que el equipo haya dado a lo
# demás.
class ElTerceroSeMudaAlRenglonDeRecepcion < ActiveRecord::Migration[8.0]
  def up
    EtiquetaPlantilla.find_each do |plantilla|
      # `read_attribute`: el jsonb tal cual, sin pasar por el reader que lo
      # envuelve en `Definicion`.
      definicion = plantilla.read_attribute(:definicion).deep_dup
      filas = definicion["filas"]
      next unless filas.is_a?(Array)

      cliente = filas.find { |f| f["id"] == "f-cliente" && f["campos"].is_a?(Array) }
      next unless cliente && cliente["campos"].include?("tercero")

      cliente["campos"] = cliente["campos"] - [ "tercero" ]
      recepcion = filas.find { |f| f["id"] == "f-recepcion" && f["campos"].is_a?(Array) }
      if recepcion
        recepcion["campos"] = (recepcion["campos"] - [ "tercero" ]) + [ "tercero" ]
      else
        filas.insert(filas.index(cliente), { "id" => "f-recepcion", "campos" => [ "tercero" ] })
      end

      plantilla.update_column(:definicion, definicion)
      say "plantilla #{plantilla.id}: el tercero se mudó al renglón de recepción"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
