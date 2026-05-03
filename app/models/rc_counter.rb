# PR-D4.d: counter atómico para tracking auto-generado de paquetes
# que CEC fue a recoletar (motorista propio fue al comercio a buscar
# / comprar algo).
#
# Formato:  RC-2026-SMI-AMZ-000001
#           └┬─┘ └┬─┘ └┬─┘ └┬─┘ └──┬───┘
#            RC  Año  Sucursal  Proveedor  Correlativo
#
# Análogo a EpCounter pero con prefijo "RC" en lugar de "EP".
# Counters separados — RC y EP no comparten secuencia.
class RcCounter < ApplicationRecord
  self.table_name = "rc_counters"

  belongs_to :sucursal
  belongs_to :proveedor

  validates :anio, presence: true,
                   numericality: { only_integer: true, greater_than: 0 }
  validates :last_value, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sucursal_id, uniqueness: { scope: [ :anio, :proveedor_id ] }

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
