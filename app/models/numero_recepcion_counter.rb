# Counter atómico de `numero_recepcion` por (sucursal, año).
#
# El `numero_recepcion` de cada paquete sigue el formato anual:
#
#   <PREFIX_SUCURSAL><AÑO 7-DÍGITOS><CONTADOR 6-DÍGITOS>
#
# Ej: `RM0002026000042` = Recibido Miami, año 2026, paquete #42 del año.
# El contador reinicia en 1 cada 1° de enero.
#
# Concurrencia: `next_for!` envuelve la lectura/escritura en una
# transacción + `lock!` (`SELECT ... FOR UPDATE`) sobre la fila
# `(sucursal_id, anio)`. Bajo carga simultánea, las escrituras se serializan
# y nunca se devuelven números duplicados. La unique index
# `(sucursal_id, anio)` evita carreras al crear la fila inicial.
class NumeroRecepcionCounter < ApplicationRecord
  self.table_name = "numero_recepcion_counters"

  belongs_to :sucursal

  validates :anio, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :ultimo_numero, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sucursal_id, uniqueness: { scope: :anio }

  # Devuelve el siguiente número (entero) para (sucursal, año) y lo persiste
  # atómicamente. Crea la fila si no existe.
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
