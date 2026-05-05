class Lugar < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de zonas/lugares
  validates :nombre, presence: true

  enum :tipo, {
    bodega_miami: "bodega_miami",
    bodega_hn: "bodega_hn",
    punto_entrega: "punto_entrega"
  }
end
