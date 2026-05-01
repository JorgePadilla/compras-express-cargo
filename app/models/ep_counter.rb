# PR-D3.b: counter atómico para tracking auto de paquetes
# ENTREGA PERSONAL.
#
# Formato confirmado por Yusef:
#
#   EP-2026-SMI-AMZ-000001
#       └┬─┘ └┬─┘ └┬─┘ └──┬───┘
#       Año Sucursal Proveedor Correlativo
#
# El correlativo va por combinación `(año, sucursal, proveedor)` —
# cada combo lleva su propio counter, así Miami-Amazon y SPS-Walmart
# no se pisan los números. Patrón análogo a `NumeroRecepcionCounter`
# (PR-A) y `ManifiestoCounter`: lock! FOR UPDATE serializa escrituras
# concurrentes; la unique index sobre (anio, sucursal_id, proveedor_id)
# evita carreras en la creación inicial.
class EpCounter < ApplicationRecord
  self.table_name = "ep_counters"

  belongs_to :sucursal
  belongs_to :proveedor

  validates :anio, presence: true,
                   numericality: { only_integer: true, greater_than: 0 }
  validates :last_value, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sucursal_id, uniqueness: { scope: [ :anio, :proveedor_id ] }

  # Devuelve el siguiente correlativo (entero) para
  # (anio, sucursal, proveedor) y lo persiste atómicamente.
  def self.next_for!(anio:, sucursal:, proveedor:)
    transaction do
      counter = lock.find_or_create_by!(
        anio: anio, sucursal_id: sucursal.id, proveedor_id: proveedor.id
      ) { |c| c.last_value = 0 }
      counter.update!(last_value: counter.last_value + 1)
      counter.last_value
    end
  end
end
