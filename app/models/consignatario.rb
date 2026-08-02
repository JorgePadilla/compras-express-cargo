class Consignatario < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de consignatarios
  validates :nombre, presence: true
end
