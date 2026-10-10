# PR-F1.1 · Fase 15. El `EEE-PPP` del número de factura SAR: establecimiento y
# punto de emisión (Acuerdo 481-2017, Art. 10 num. 7 a-b).
#
# Jorge, 2026-10-10: *un punto de emisión por sucursal que factura* —Zeron SPS,
# Humuya TGU, San Manuel—, y la factura sale del punto de la sucursal de quien
# factura. Por eso `sucursal_id` es único, y solo una sucursal de Honduras
# puede tener uno: Miami recibe carga, no factura.
class PuntoDeEmision < ApplicationRecord
  has_paper_trail
  self.table_name = "puntos_de_emision"

  belongs_to :sucursal
  has_many :autorizaciones_sar, dependent: :restrict_with_error
  has_many :correlativos_fiscales, dependent: :restrict_with_error
  has_many :asientos_fiscales, dependent: :restrict_with_error

  TRES_DIGITOS = /\A\d{3}\z/

  validates :establecimiento, :punto, format: { with: TRES_DIGITOS, message: "debe tener 3 dígitos" }
  validates :sucursal_id, uniqueness: { message: "ya tiene un punto de emisión" }
  validates :punto, uniqueness: { scope: :establecimiento, message: "ya está asignado con ese establecimiento" }
  validate :sucursal_de_honduras
  validate :numeros_fijos_con_autorizaciones, on: :update

  scope :activos, -> { where(activo: true) }

  # El «identificador del documento» de la gema: `EEE-PPP-TT`. Es la llave con
  # la que se piden número y autorización.
  def identificador(tipo_documento)
    tipo = tipo_documento.to_s
    unless Fiscal::TIPOS_DE_DOCUMENTO.key?(tipo)
      raise ArgumentError, "tipo de documento no reconocido: #{tipo.inspect}"
    end

    "#{establecimiento}-#{punto}-#{tipo}"
  end

  def to_s
    "#{establecimiento}-#{punto} · #{sucursal&.nombre}"
  end

  # Para el formulario: el `EEE-PPP` sin el tipo.
  def prefijo
    "#{establecimiento}-#{punto}"
  end

  private

  # PR-F1.3 · La SAR autoriza cada CAI para un `EEE-PPP` y una sucursal. Con la
  # pantalla, cambiar los números o la sucursal de un punto que ya tiene CAIs
  # cargados dejaría esos CAIs apuntando a otro establecimiento. Se carga un
  # punto nuevo; `activo` sí se puede tocar.
  def numeros_fijos_con_autorizaciones
    return unless (changed & %w[establecimiento punto sucursal_id]).any?
    return unless autorizaciones_sar.exists?

    errors.add(:base, "Ya tiene autorizaciones cargadas: la sucursal y los números no se cambian")
  end

  def sucursal_de_honduras
    return if sucursal.nil? || sucursal.ubicacion == "honduras"

    errors.add(:sucursal, "tiene que ser de Honduras: solo ahí se factura")
  end
end
