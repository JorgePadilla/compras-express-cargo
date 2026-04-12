class CategoriaPrecio < ApplicationRecord
  has_many :clientes, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
  validates :precio_libra_aereo, :precio_libra_maritimo,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Returns the price per pound for the given tipo_envio, selecting aereo or
  # maritimo based on the shipment modalidad. Falls back to nil if the
  # category does not override that modalidad; callers should then use
  # `tipo_envio.precio_libra` as the default.
  def precio_para(tipo_envio)
    return nil if tipo_envio.nil?

    case tipo_envio.modalidad
    when "aereo"    then precio_libra_aereo
    when "maritimo" then precio_libra_maritimo
    end
  end

  def to_s
    nombre
  end
end
