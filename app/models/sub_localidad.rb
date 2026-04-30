# PR-D1.c: bodega interna o área tercera dentro de una Sucursal. Sirve
# para identificar dónde está físicamente un paquete. Spec Yusef
# 2026-04-29: "zerón en la sucursal y zr01 (bodega central), zr02
# (bodega cem) y así sucesivamente, ya que hay cargas que las ponemos
# en áreas terceras".
class SubLocalidad < ApplicationRecord
  self.table_name = "sub_localidades"

  belongs_to :sucursal
  has_many :paquetes_actuales, class_name: "Paquete",
           foreign_key: :sub_localidad_actual_id, dependent: :nullify

  validates :codigo, presence: true, uniqueness: { scope: :sucursal_id, case_sensitive: false }
  validates :nombre, presence: true

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :codigo) }

  def to_s
    "#{codigo} · #{nombre}"
  end
end
