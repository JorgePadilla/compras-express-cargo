# PR-D3.a: catálogo de proveedores (Amazon, Walmart, eBay, drivers
# privados, etc.). Yusef pidió un listado con autocomplete (igual al
# de clientes) y que el operador pueda agregar nuevos sin tocar seeds.
#
# El `codigo` (3 chars) se genera automáticamente desde el nombre y se
# usa para construir el tracking interno de paquetes ENTREGA PERSONAL
# (ej. EP-2026-SM-AMZ-000001). Es editable manualmente en caso de
# colisión o si admin quiere un alias distinto.
class Proveedor < ApplicationRecord
  # Defensivo: el inflector irregular `proveedor ↔ proveedores` está
  # configurado en config/initializers/inflections.rb, pero forzar el
  # table_name acá protege contra cualquier orden de autoload donde el
  # modelo se cargue antes del initializer.
  self.table_name = "proveedores"

  TIPOS = %w[comercio entrega_personal].freeze

  has_many :paquetes, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
  validates :codigo, presence: true, uniqueness: { case_sensitive: false },
                     length: { in: 2..8 },
                     format: { with: /\A[A-Z0-9]+\z/, message: "solo letras mayúsculas y números" }
  validates :tipo, inclusion: { in: TIPOS }

  before_validation :generar_codigo, if: -> { codigo.blank? && nombre.present? }
  before_validation :normalizar_codigo

  scope :activos, -> { where(activo: true) }
  scope :ordered, -> { order(:position, :nombre) }
  scope :buscar, ->(term) {
    return all if term.blank?
    where("nombre ILIKE :q OR codigo ILIKE :q",
          q: "%#{sanitize_sql_like(term)}%")
  }

  def to_s
    nombre
  end

  def entrega_personal?
    tipo == "entrega_personal"
  end

  # PR-D3.a: codigo de 3 letras derivado del nombre. Si el candidato ya
  # existe, agrega un sufijo numérico (AMZ → AMZ2 → AMZ3) hasta hallar
  # uno libre. Mantiene el codigo a 3 chars cuando se puede; se alarga
  # sólo si hubo colisión.
  def self.generar_codigo_desde(nombre)
    base = nombre.to_s
                 .unicode_normalize(:nfkd)
                 .gsub(/[^A-Za-z]/, "")
                 .upcase
                 .first(3)
    return nil if base.blank?

    candidato = base
    n = 1
    while exists?(codigo: candidato)
      n += 1
      candidato = "#{base}#{n}"
    end
    candidato
  end

  private

  def generar_codigo
    self.codigo = self.class.generar_codigo_desde(nombre)
  end

  def normalizar_codigo
    return if codigo.blank?
    self.codigo = codigo.to_s.upcase.gsub(/\s+/, "")
  end
end
