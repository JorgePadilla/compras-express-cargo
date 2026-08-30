class PreFacturaItem < ApplicationRecord
  include Descontable

  # PR-D6.b: origen de la línea para distinguir cargos auto de manuales.
  # `manual` = línea de paquete o agregada por el cajero a mano.
  # `auto_recolecta` = generada desde paquete.recolecta_solicitada.
  # `auto_servicio_extra` = generada desde paquete.solicito_cambio_servicio.
  ORIGENES = %w[manual auto_recolecta auto_servicio_extra].freeze

  belongs_to :pre_factura, inverse_of: :pre_factura_items
  # PR-13.d: `nullify` y no `destroy` — si se elimina la línea, el registro de
  # que un supervisor autorizó eliminarla tiene que quedar.
  has_many :autorizaciones, dependent: :nullify
  belongs_to :paquete, optional: true
  belongs_to :tarifa_recolecta, optional: true
  belongs_to :servicio_extra, optional: true

  validates :concepto, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }
  validates :origen, inclusion: { in: ORIGENES }

  scope :auto, -> { where("origen LIKE 'auto_%'") }
  scope :manual, -> { where(origen: "manual") }

  before_validation :calculate_subtotal_from_peso

  # PR-M8. Contrapeso de `PreFactura#vincular_paquetes`. Desde que el paquete
  # queda estampado con `pre_factura_id`, borrar su línea sin soltarlo lo dejaba
  # fuera de `facturables` **para siempre**: `cobrada_o_entregada?` seguía en
  # true y ni se podía volver a facturar ni borrar.
  #
  # Se borra una línea por dos vías, y las dos pasan por acá: la autorización
  # con PIN (`Autorizacion#aplicar`, acción «eliminar») y el `dependent:
  # :destroy` de la pre-factura.
  #
  # El `exists?` importa: un paquete puede tener **varias** líneas en el mismo
  # documento —el flete y sus cargos automáticos de recolecta o cambio de
  # servicio—, y `PreFactura#aplicar_cobros_automaticos_para` las borra y
  # rearma. Soltar el paquete al morir una línea auto lo sacaría del cobro con
  # su flete todavía puesto.
  after_destroy :soltar_paquete_si_quedo_sin_lineas

  private def soltar_paquete_si_quedo_sin_lineas
    return if paquete_id.blank?
    return if PreFacturaItem.where(pre_factura_id: pre_factura_id, paquete_id: paquete_id).exists?

    Paquete.where(id: paquete_id, pre_factura_id: pre_factura_id).update_all(pre_factura_id: nil)
  end
  public

  def auto?
    origen.to_s.start_with?("auto_")
  end

  private

  # PR-10.a: `minimo_aplicado` protege los dos casos donde el subtotal NO sale
  # de peso × precio — el cobro mínimo de servicio y el simbólico de prepagado
  # en Miami. Sin ese guard, este callback los pisaba en silencio.
  def calculate_subtotal_from_peso
    return if minimo_aplicado?
    return unless peso_cobrar.present? && precio_libra.present?

    self.subtotal = (peso_cobrar.to_d * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
