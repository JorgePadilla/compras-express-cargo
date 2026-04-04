class Consignatario < ApplicationRecord
  validates :nombre, presence: true
end
