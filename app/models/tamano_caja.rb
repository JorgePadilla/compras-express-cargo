class TamanoCaja < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de cambios al catálogo
  validates :nombre, presence: true
end
