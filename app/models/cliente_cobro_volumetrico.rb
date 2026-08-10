# PR-C6.41 · RP-04b: la fila ES el flag.
#
# Que exista `(cliente, tipo_envio)` significa que a ese cliente, en ese
# servicio, se le cobra **solo el volumétrico** — no el mayor entre peso real y
# volumétrico, que es el default de todos los demás.
#
# `has_paper_trail` no es decorativo: prender esta fila **baja lo que se le
# cobra al cliente**. El audit de `Cliente` no ve inserts ni deletes de esta
# tabla, así que sin esto no quedaría rastro de quién le dio la tarifa especial
# a quién.
class ClienteCobroVolumetrico < ApplicationRecord
  has_paper_trail

  belongs_to :cliente
  belongs_to :tipo_envio

  validates :cliente_id, uniqueness: { scope: :tipo_envio_id }
end
