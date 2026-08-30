# C21-08 · A quién va consignada la carga — «CORPORACION KARSAM».
#
# El modelo existía desde `PR-D7` y estaba **vacío por dentro**: sin una fila,
# sin pantalla y sin asociaciones. Yusef lo pidió entre los catálogos que quiere
# poder llenar él —*"qué consignatario somos nosotros"*— y por eso ahora tiene
# CRUD.
#
# Ojo: «CORPORACION KARSAM» también vive en `Agent`, que es el bloque *Agent*
# del Warehouse Receipt y significa «agente de destino». Jorge decidió
# (2026-08-30) poblar `Consignatario`, que es el nombre correcto para el
# manifiesto, y dejar `Agent` como está.
class Consignatario < ApplicationRecord
  has_paper_trail

  validates :nombre, presence: true

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:nombre) }

  def to_s = nombre
end
