# PR-13.d/e: un cambio que un supervisor autorizó con su PIN.
#
# Cubre dos momentos distintos, porque son dos negocios distintos:
#
#   - **Línea de pre-factura** (13.d): el precio sale de la tabla de tarifas y
#     tiene que salir preestablecido. Cambiarlo es la excepción, así que el
#     candado va por línea.
#
#   - **Emisión de una nota** (13.e): la nota NO saca su monto de una tarifa —
#     su propósito es ajustar a mano. Trabar cada línea sería trabar lo que el
#     documento viene a hacer. El control va al **emitir**, que es cuando el
#     saldo del cliente cambia.
#
# En los dos casos el principio es el mismo: **autorizar y aplicar son el mismo
# acto**. No hay un modo "desbloqueado" — el supervisor está parado ahí, el
# formulario recoge el cambio y el PIN juntos, y esto los aplica en una
# transacción o en ninguna.
class Autorizacion < ApplicationRecord
  self.table_name = "autorizaciones"

  ACCIONES_LINEA = %w[precio peso descuento eliminar].freeze
  ACCIONES = (ACCIONES_LINEA + %w[emitir]).freeze

  # Virtuales: llegan del formulario, no se guardan.
  attr_accessor :pin, :valor, :modo

  belongs_to :documento, polymorphic: true
  belongs_to :pre_factura_item, optional: true
  belongs_to :autorizado_por, class_name: "User"
  belongs_to :solicitado_por, class_name: "User"

  validates :accion, inclusion: { in: ACCIONES }
  validates :concepto, presence: true
  validates :motivo, presence: { message: "es obligatorio — es el punto del registro" }
  validate  :autorizante_habilitado
  validate  :pin_correcto
  # Cuatro ojos: quien armó la nota no la emite él mismo. Es donde de verdad se
  # mueve el saldo del cliente, y una nota de crédito es plata que se devuelve.
  #
  # Va como `validate` y no como chequeo suelto antes de `valid?`: `valid?`
  # limpia los errores, así que un `errors.add` previo se perdía en silencio.
  validate  :cuatro_ojos, if: -> { accion == "emitir" }

  scope :recientes, -> { order(created_at: :desc) }
  scope :by_accion, ->(a) { where(accion: a) }
  scope :by_autorizante, ->(id) { where(autorizado_por_id: id) }

  # ── Línea de pre-factura ────────────────────────────────────────────────

  def self.aplicar_a_linea!(item:, solicitado_por:, attrs:)
    autorizacion = new(
      documento: item.pre_factura,
      pre_factura_item: item,
      solicitado_por: solicitado_por,
      autorizado_por_id: attrs[:autorizado_por_id],
      accion: attrs[:accion],
      motivo: attrs[:motivo],
      concepto: item.concepto,
      pin: attrs[:pin], valor: attrs[:valor], modo: attrs[:modo]
    )
    unless attrs[:accion].to_s.in?(ACCIONES_LINEA)
      autorizacion.errors.add(:accion, "no aplica a una linea")
      return autorizacion
    end

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

  # ── Emisión de una nota de débito o crédito ─────────────────────────────

  # Autoriza y emite. Si el PIN no cuadra, o la autoriza la misma persona que la
  # creó, la nota se queda en `creado` y el saldo del cliente no se toca.
  def self.emitir_nota!(nota:, solicitado_por:, attrs:)
    autorizacion = new(
      documento: nota,
      solicitado_por: solicitado_por,
      autorizado_por_id: attrs[:autorizado_por_id],
      accion: "emitir",
      motivo: attrs[:motivo],
      concepto: "#{nota.numero} · #{nota.cliente.nombre_completo}",
      pin: attrs[:pin],
      valor_nuevo: nota.total,
      detalle: nota.model_name.human
    )
    return autorizacion unless autorizacion.valid?

    transaction do
      raise ActiveRecord::Rollback unless nota.emitir!
      autorizacion.save!
    end

    autorizacion.persisted? ? autorizacion : autorizacion.tap { |a|
      a.errors.add(:base, "No se pudo emitir (estado actual: #{nota.estado}).")
    }
  end

  # ── Snapshots ───────────────────────────────────────────────────────────

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
      "descuento" => "Descuento", "eliminar" => "Línea eliminada",
      "emitir" => "Nota emitida" }[accion]
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

    errors.add(:autorizado_por, "no tiene PIN de autorizacion o su rol no autoriza")
  end

  def pin_correcto
    return if autorizado_por.nil?
    return if autorizado_por.authenticate_pin(pin.to_s)

    errors.add(:pin, "incorrecto")
  end

  def cuatro_ojos
    return if documento&.creado_por_id.nil?
    return if autorizado_por_id.to_i != documento.creado_por_id

    errors.add(:autorizado_por, "no puede ser quien creo la nota — tiene que autorizarla otra persona")
  end
end
