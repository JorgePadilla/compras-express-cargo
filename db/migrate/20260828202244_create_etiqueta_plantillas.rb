class CreateEtiquetaPlantillas < ActiveRecord::Migration[8.0]
  # C19-06, la mitad que faltaba: la PLANTILLA de la etiqueta editable por
  # Yusef. Un singleton con la definición entera en jsonb: sin registro, rige
  # el default de fábrica que vive en el código (EtiquetaPlantilla::Definicion)
  # — así «restaurar la original» es borrar el registro, y el deploy-no-siembra
  # ni aplica.
  def change
    create_table :etiqueta_plantillas do |t|
      t.jsonb :definicion, null: false, default: {}

      t.timestamps
    end
  end
end
