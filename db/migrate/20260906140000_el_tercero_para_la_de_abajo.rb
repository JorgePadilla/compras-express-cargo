# C25-07 · El tercero, por fin, «para acá abajo»: tercera línea de la columna
# izquierda del bloque inferior, debajo de dónde retira.
#
# El `DEFAULT` ya cambió, pero una plantilla guardada no lo lee
# (`Definicion#filas` toma la suya). Idempotente: saca `tercero` de cualquier
# fila de arriba donde esté —`f-recepcion` desde el 2026-09-06 por la mañana,
# `f-cliente` en las anteriores—, borra la fila si quedó vacía, y lo agrega
# como subfila propia al final de `izquierda` si no está ya en el bloque.
class ElTerceroParaLaDeAbajo < ActiveRecord::Migration[8.0]
  def up
    EtiquetaPlantilla.find_each do |plantilla|
      definicion = plantilla.read_attribute(:definicion).deep_dup
      filas = definicion["filas"]
      next unless filas.is_a?(Array)

      bloque = filas.find { |f| f["tipo"] == "dos_columnas" && f["izquierda"].is_a?(Array) }
      next unless bloque

      arriba = filas.select { |f| f["campos"].is_a?(Array) && f["campos"].include?("tercero") }
      adentro = (bloque["izquierda"] + Array(bloque["derecha"])).flatten.include?("tercero")
      next if arriba.empty? && adentro

      arriba.each { |f| f["campos"] = f["campos"] - [ "tercero" ] }
      filas.reject! { |f| f["campos"].is_a?(Array) && f["campos"].empty? }
      bloque["izquierda"] << [ "tercero" ] unless adentro

      plantilla.update_column(:definicion, definicion)
      say "plantilla #{plantilla.id}: el tercero bajó al bloque inferior"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
