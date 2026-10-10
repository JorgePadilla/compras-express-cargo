class Empresa < ApplicationRecord
  has_paper_trail  # PR-D7: audit log — datos de empresa, ISV
  has_one_attached :logo
  include ConRtn  # PR-F1.1: el RTN del emisor en la factura SAR

  validates :nombre, presence: true
  # PR-F2.1 · El ISV lo calcula la gema con la tarifa general (15 %), no con
  # esta columna: un 18 % acá haría que el PDF dijera una tasa y la factura
  # cobrara otra. Así que la columna solo puede valer eso. F1.4 saca el campo
  # del formulario.
  validates :isv_rate, numericality: { equal_to: Invoicehn::TaxTreatment::GRAVADO_15.rate }

  def self.instance
    first_or_create!(nombre: "Compras Express Cargo")
  end

  def logo_file_path
    return nil unless logo.attached?

    service = ActiveStorage::Blob.service
    service.respond_to?(:path_for) ? service.path_for(logo.key) : nil
  end
end
