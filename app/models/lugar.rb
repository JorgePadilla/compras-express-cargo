class Lugar < ApplicationRecord
  validates :nombre, presence: true

  enum :tipo, {
    bodega_miami: "bodega_miami",
    bodega_hn: "bodega_hn",
    punto_entrega: "punto_entrega"
  }
end
