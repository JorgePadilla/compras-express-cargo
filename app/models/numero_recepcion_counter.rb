# Counter atómico de `numero_recepcion` por (sucursal, año, MES).
#
# El `numero_recepcion` de cada paquete sigue el formato anual:
#
#   R<CÓDIGO SUCURSAL><AÑO 2><MES 2><CONTADOR 6>
#
# Ej: `RMIA2612000042` = Recibido en Miami, diciembre de 2026, paquete #42 del
# mes. El contador reinicia en 1 cada mes — PR-C6.40, pedido por Yusef en la
# pregunta 17 del cuestionario.
#
# Concurrencia: `next_for!` envuelve la lectura/escritura en una
# transacción + `lock!` (`SELECT ... FOR UPDATE`) sobre la fila
# `(sucursal_id, anio, mes)`. Bajo carga simultánea, las escrituras se serializan
# y nunca se devuelven números duplicados. La unique index
# `(sucursal_id, anio, mes)` evita carreras al crear la fila inicial.
class NumeroRecepcionCounter < ApplicationRecord
  self.table_name = "numero_recepcion_counters"

  belongs_to :sucursal

  validates :anio, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :ultimo_numero, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :mes, presence: true, numericality: { only_integer: true, in: 0..12 }
  validates :sucursal_id, uniqueness: { scope: %i[anio mes] }

  # Devuelve el siguiente número (entero) para (sucursal, año) y lo persiste
  # atómicamente. Crea la fila si no existe.
  def self.next_for!(sucursal:, anio:, mes:)
    transaction do
      counter = lock.find_or_create_by!(sucursal_id: sucursal.id, anio: anio, mes: mes) do |c|
        c.ultimo_numero = 0
      end
      counter.update!(ultimo_numero: counter.ultimo_numero + 1)
      counter.ultimo_numero
    end
  end
end
