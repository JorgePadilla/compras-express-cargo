class Configuracion < ApplicationRecord
  validates :clave, presence: true, uniqueness: true

  def self.get(clave)
    find_by(clave: clave)&.valor
  end

  def self.set(clave, valor, tipo: "string", categoria: "general")
    record = find_or_initialize_by(clave: clave)
    record.update!(valor: valor, tipo: tipo, categoria: categoria)
  end
end
