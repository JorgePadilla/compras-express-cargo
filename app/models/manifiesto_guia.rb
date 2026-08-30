# C21-11 · Un número de guía del proveedor.
#
# Son varios, no uno: *"el número de guía termina siendo varios"*. Y tienen la
# forma que Yusef reconoció como la nuestra — `286441-1`, `286441-2`,
# `286441-3`: *"es el mismo número, solo tiene el 1, el 2 y el 3. Es el mismo
# que nosotros, la misma teoría"*.
#
# **No es obligatoria al crear el manifiesto**: la llena después San Pedro Sula
# —*"le ingresa la encargada de operaciones en San Pedro Sula"*—, así que la
# tabla puede quedar vacía y el manifiesto es válido igual.
class ManifiestoGuia < ApplicationRecord
  belongs_to :manifiesto, inverse_of: :guias

  validates :numero, presence: true,
                     uniqueness: { scope: :manifiesto_id, case_sensitive: false }
end
