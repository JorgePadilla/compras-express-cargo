class CategoriaPrecio < ApplicationRecord
  has_many :clientes

  validates :nombre, presence: true
end
