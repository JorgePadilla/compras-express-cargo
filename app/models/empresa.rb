class Empresa < ApplicationRecord
  has_one_attached :logo

  validates :nombre, presence: true
  validates :isv_rate, numericality: { greater_than_or_equal_to: 0, less_than: 1 }

  def self.instance
    first_or_create!(nombre: "Compras Express Cargo")
  end

  def logo_file_path
    return nil unless logo.attached?

    service = ActiveStorage::Blob.service
    service.respond_to?(:path_for) ? service.path_for(logo.key) : nil
  end
end
