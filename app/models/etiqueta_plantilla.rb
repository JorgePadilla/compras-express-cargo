# C19-06: la plantilla de la etiqueta, editable por Yusef desde
# /ajustes_etiqueta. "¿Vos no tenés en el sistema donde yo pueda cambiarlas
# yo? El tamaño… a mí me habían dado esto [en el legacy] para no molestar."
#
# Es un singleton: sin registro rige el **default de fábrica**, que vive como
# constante en `Definicion` — la original ES el código, así que «restaurar la
# original» (que en el legacy era "tengo que grabar las originales") es borrar
# el registro, y el deploy —que solo migra, nunca siembra— no necesita nada.
#
# paper_trail guarda quién y cuándo; el historial se muestra como resumen,
# nunca el diff del JSON crudo.
class EtiquetaPlantilla < ApplicationRecord
  has_paper_trail

  def self.singleton
    first_or_initialize
  end

  # La definición que rige la impresión, siempre usable: sin registro, con el
  # registro roto o con valores basura, `Definicion` clampa y cae al default.
  # El path de impresión jamás tira 500 ni manda basura a la Dymo.
  def self.vigente
    Definicion.new(first&.definicion)
  rescue StandardError => e
    Rails.logger.warn "[etiqueta] plantilla ilegible, rige la de fábrica: #{e.message}"
    Definicion.new(nil)
  end

  def self.restaurar_original!
    first&.destroy!
  end
end
