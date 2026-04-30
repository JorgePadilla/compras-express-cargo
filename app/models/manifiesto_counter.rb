# PR-D1.d: counter atómico de números de manifiesto por (sucursal, año),
# análogo a `NumeroRecepcionCounter`. Cada `Manifiesto` nuevo recibe un
# número en formato anual `M<letra-sucursal><año 4-dig><contador 6-dig>`.
class ManifiestoCounter < ApplicationRecord
  self.table_name = "manifiesto_counters"

  belongs_to :sucursal

  validates :anio, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :ultimo_numero, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sucursal_id, uniqueness: { scope: :anio }

  # Devuelve el siguiente número entero atómicamente. Lock FOR UPDATE en
  # la fila garantiza que dos creates concurrentes no compartan el mismo
  # número.
  def self.next_for!(sucursal:, anio:)
    transaction do
      counter = lock.find_or_create_by!(sucursal_id: sucursal.id, anio: anio) do |c|
        c.ultimo_numero = 0
      end
      counter.update!(ultimo_numero: counter.ultimo_numero + 1)
      counter.ultimo_numero
    end
  end
end
