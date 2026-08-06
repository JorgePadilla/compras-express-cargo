# PR-13.d: un cambio autorizado por un supervisor sobre una línea de
# pre-factura.
#
# El principio del diseño: **autorizar y cambiar son el mismo acto**. No existe
# un modo "desbloqueado". El supervisor está parado en el mostrador, así que el
# modal recoge el cambio y el PIN juntos y acá se aplican en una transacción.
#
# La alternativa —el PIN abre una ventana de edición— tiene dos problemas: el
# registro puede quedar desalineado del cambio (se autoriza una cosa y se guarda
# otra) y la ventana queda abierta cuando el supervisor ya se fue.
class AutorizacionLinea < ApplicationRecord
  self.table_name = "autorizaciones_linea"

  ACCIONES = %w[precio peso descuento eliminar].freeze

  # Virtuales: llegan del modal, no se guardan.
  attr_accessor :pin, :valor, :modo

  belongs_to :pre_factura
  belongs_to :pre_factura_item, optional: true
  belongs_to :autorizado_por, class_name: "User"
  belongs_to :solicitado_por, class_name: "User"

  validates :accion, inclusion: { in: ACCIONES }
  validates :concepto, presence: true
  validates :motivo, presence: { message: "es obligatorio — es el punto del registro" }
  validate  :autorizante_habilitado
  validate  :pin_correcto

  scope :recientes, -> { order(created_at: :desc) }
  scope :by_accion, ->(a) { where(accion: a) }
  scope :by_autorizante, ->(id) { where(autorizado_por_id: id) }

  # Aplica el cambio y lo registra, o no hace ninguna de las dos cosas.
  #
  # Devuelve la autorización. Si no es válida (PIN malo, rol que no autoriza,
  # sin motivo) vuelve sin persistir y con los errores puestos.
  def self.aplicar!(item:, solicitado_por:, attrs:)
    autorizacion = new(
      pre_factura: item.pre_factura,
      pre_factura_item: item,
      solicitado_por: solicitado_por,
      autorizado_por_id: attrs[:autorizado_por_id],
      accion: attrs[:accion],
      motivo: attrs[:motivo],
      concepto: item.concepto,
      pin: attrs[:pin],
      valor: attrs[:valor],
      modo: attrs[:modo]
    )

    autorizacion.snapshot_anterior(item)
    return autorizacion unless autorizacion.valid?

    transaction do
      autorizacion.aplicar_a(item)
      # El valor nuevo se lee del item DESPUÉS de aplicar, no de lo que mandó el
      # form: con un descuento capturado como "10%" lo que hay que registrar es
      # el monto que resultó (L.111.83), que es lo que se regaló. Si se guardara
      # el 10, el total de la bitácora sumaría porcentajes con lempiras.
      autorizacion.snapshot_nuevo(item)
      autorizacion.save!
      # Los totales del documento viven en `pre_factura` y se recalculan en su
      # `before_save`, que no corre al guardar un item suelto.
      item.pre_factura.reload.save!
    end

    autorizacion
  end

  # Contra qué se autorizó. Va antes de tocar nada: si la tarifa se mueve
  # después, este es el único rastro del valor original.
  def snapshot_anterior(item)
    self.valor_anterior = case accion
    when "precio"    then item.precio_libra
    when "peso"      then item.peso_cobrar
    when "descuento" then item.descuento_monto
    when "eliminar"  then item.total_linea
    end
    self.detalle = detalle_legible(item)
  end

  def snapshot_nuevo(item)
    self.valor_nuevo = case accion
    when "precio"    then item.precio_libra
    when "peso"      then item.peso_cobrar
    when "descuento" then item.descuento_monto
    when "eliminar"  then nil
    end
  end

  def aplicar_a(item)
    case accion
    when "precio"
      item.update!(precio_libra: valor.to_d)
    when "peso"
      item.update!(peso_cobrar: valor.to_d)
    when "descuento"
      if modo.to_s == "porcentaje"
        item.aplicar_descuento_porcentaje(valor)
      else
        item.aplicar_descuento_monto(valor)
      end
      item.descuento_motivo = motivo
      item.save!
    when "eliminar"
      item.destroy!
      self.pre_factura_item = nil
    end
  end

  def accion_label
    { "precio" => "Precio por libra", "peso" => "Peso a cobrar",
      "descuento" => "Descuento", "eliminar" => "Línea eliminada" }[accion]
  end

  private

  def detalle_legible(item)
    case accion
    when "descuento"
      modo.to_s == "porcentaje" ? "#{valor}% sobre #{item.subtotal.to_f}" : "monto fijo"
    when "eliminar"
      "se quitó de la pre-factura"
    end
  end

  # El PIN identifica a la persona, pero el rol es lo que la habilita: un cajero
  # con el PIN de un supervisor tampoco autoriza.
  def autorizante_habilitado
    return if autorizado_por&.puede_autorizar?

    errors.add(:autorizado_por, "no puede autorizar cambios de precio")
  end

  def pin_correcto
    return if autorizado_por.nil?
    return if autorizado_por.authenticate_pin(pin.to_s)

    errors.add(:pin, "incorrecto")
  end
end
