class Manifiesto < ApplicationRecord
  has_paper_trail  # PR-D1.a: audit log

  belongs_to :empresa_manifiesto, optional: true
  belongs_to :sucursal_origen, class_name: "Sucursal", optional: true  # PR-D1.d
  belongs_to :user, optional: true
  has_many :paquetes, dependent: :nullify

  enum :estado, {
    creado: "creado",
    enviado: "enviado",
    en_aduana: "en_aduana",
    recibido: "recibido"
  }

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true

  scope :activos, -> { where(activo: true) }
  scope :buscar, ->(term) {
    where("numero ILIKE :q OR numero_guia ILIKE :q", q: "%#{sanitize_sql_like(term)}%")
  }
  scope :by_estado, ->(estado) { where(estado: estado) }

  before_validation :generate_numero, on: :create, if: -> { numero.blank? }

  def save(**args, &block)
    super
  rescue ActiveRecord::RecordNotUnique => e
    raise unless new_record? && e.message.include?("numero") && (@_numero_retries ||= 0) < 3
    @_numero_retries += 1
    self.numero = nil
    generate_numero
    retry
  end

  def recalculate_totals!
    update!(
      cantidad_paquetes: paquetes.count,
      peso_total: paquetes.sum(:peso_cobrar),
      volumen_total: paquetes.sum(:volumen)
    )
  end

  def enviar!
    transaction do
      update!(estado: "enviado", fecha_enviado: Time.current)
      paquetes.update_all(estado: "enviado_honduras", fecha_enviado: Time.current)
    end
  end

  private

  # PR-D1.d: nuevo formato anual `M<letra-sucursal><año 4-dig><contador 6-dig>`.
  # Ejemplos: MM2026000001 (Miami), MS2026000042 (SPS), MT2026000001 (Humuya).
  # Si no hay sucursal_origen (manifiestos legacy o tests), cae al formato
  # antiguo `MA-XXXXXX` para no romper la creación.
  def generate_numero
    if sucursal_origen.present?
      letra = sucursal_origen.codigo.to_s[0]&.upcase || "X"
      anio = (fecha_enviado&.year || created_at&.year || Time.zone.now.year)
      next_number = ManifiestoCounter.next_for!(sucursal: sucursal_origen, anio: anio)
      self.numero = format("M%<letra>s%<anio>04d%<num>06d", letra: letra, anio: anio, num: next_number)
    else
      # Fallback legacy
      next_number = (self.class.where("numero LIKE 'MA-%'").maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
      self.numero = "MA-#{next_number.to_s.rjust(6, '0')}"
    end
  end
end
