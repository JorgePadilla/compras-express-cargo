class EntregaPaquete < ApplicationRecord
  belongs_to :entrega
  belongs_to :paquete

  validates :paquete_id, uniqueness: { scope: :entrega_id }
end
