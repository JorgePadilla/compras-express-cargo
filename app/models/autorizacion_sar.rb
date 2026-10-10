# PR-F1.1 · Fase 15. Una autorización de la SAR: el CAI, el rango de números
# autorizado y la fecha límite de emisión, por punto de emisión y tipo de
# documento (Acuerdo 481-2017, Arts. 10 num. 3-5 y 59).
#
# Jorge, 2026-10-10: *sin CAI real todavía*. Se cargan por pantalla (F1.3), y
# en staging va uno inventado (`ficticia`, F1.5) que en producción no se acepta.
#
# Las reglas, y dónde vive cada una:
# - Dos rangos del mismo punto y tipo no se pisan: `EXCLUDE` en la base
#   (`autorizaciones_sar_sin_solapar`) **y** acá, que da el mensaje y sirve si
#   una base no tuviera `btree_gist`.
# - Un rango nuevo arranca arriba del último número ya emitido: si no, la
#   autorización nace con números que ya se usaron.
# - Una vez que se emitió con ella, no se edita ni se borra: el CAI y el rango
#   están impresos en documentos entregados.
class AutorizacionSar < ApplicationRecord
  has_paper_trail
  self.table_name = "autorizaciones_sar"

  belongs_to :punto_de_emision
  belongs_to :cargada_por, class_name: "User", optional: true

  # El CAI se guarda tal cual lo dio la SAR: el Acuerdo no le fija largo ni
  # formato (ver `Invoicehn::Authorization`). Solo se le sacan los espacios de
  # las puntas, que vienen de copiar y pegar.
  normalizes :cai, with: ->(cai) { cai.to_s.strip }

  validates :tipo_documento, inclusion: { in: Fiscal::TIPOS_DE_DOCUMENTO.keys, message: "no es un tipo de documento que se emita" }
  validates :cai, :fecha_limite_emision, presence: true
  validates :rango_inicio, :rango_fin,
            numericality: { only_integer: true, greater_than_or_equal_to: 1,
                            less_than_or_equal_to: Fiscal::CORRELATIVO_MAXIMO }
  validate :rango_en_orden
  validate :sin_solapar
  validate :arriba_de_lo_emitido
  validate :ficticia_fuera_de_produccion
  validate :intocable_si_ya_se_emitio, on: :update

  before_destroy :no_borrar_si_ya_se_emitio

  scope :del, ->(punto, tipo) { where(punto_de_emision: punto, tipo_documento: tipo.to_s) }
  scope :reales, -> { where(ficticia: false) }

  # `EEE-PPP-TT`, la llave de la gema.
  def identificador
    punto_de_emision.identificador(tipo_documento)
  end

  def capacidad
    rango_fin - rango_inicio + 1
  end

  # Art. 62: la fecha límite es el último día en que se puede emitir.
  def vencida?(al = Fiscal.hoy)
    al > fecha_limite_emision
  end

  # El correlativo de su punto y tipo, el que cuenta lo emitido.
  def correlativo
    CorrelativoFiscal.find_by(punto_de_emision_id: punto_de_emision_id, tipo_documento: tipo_documento)
  end

  # Si ya salió algún número de este rango. Los números se asignan sin huecos y
  # en la misma transacción que guarda el documento (F1.2), así que «el
  # correlativo llegó al inicio del rango» es lo mismo que «hay documentos con
  # este CAI». Mira lo guardado, no lo que se está editando.
  def documentos_emitidos?
    return false if new_record?

    CorrelativoFiscal.where(punto_de_emision_id: punto_de_emision_id_in_database,
                            tipo_documento: tipo_documento_in_database)
                     .where(ultimo: rango_inicio_in_database..)
                     .exists?
  end

  # TODO(PR-F1.2): `#to_invoicehn` → `Invoicehn::Authorization`, cuando entre
  # la gema 0.2.0 (D8 de FISCAL.md).

  private

  def rango_en_orden
    return unless rango_inicio && rango_fin && rango_inicio > rango_fin

    errors.add(:rango_fin, "no puede ser menor que el inicio del rango")
  end

  def sin_solapar
    return unless punto_de_emision_id && tipo_documento && rango_inicio && rango_fin

    pisada = self.class.where(punto_de_emision_id: punto_de_emision_id, tipo_documento: tipo_documento)
                       .where.not(id: id)
                       .where("rango_inicio <= ? AND rango_fin >= ?", rango_fin, rango_inicio)
                       .first
    return unless pisada

    errors.add(:base, "El rango se pisa con el de la autorización #{pisada.cai} " \
                      "(#{pisada.rango_inicio}–#{pisada.rango_fin})")
  end

  def arriba_de_lo_emitido
    return unless rango_inicio && punto_de_emision_id && tipo_documento
    return unless new_record? || will_save_change_to_rango_inicio? ||
                  will_save_change_to_punto_de_emision_id? || will_save_change_to_tipo_documento?

    ultimo = correlativo&.ultimo.to_i
    return if rango_inicio > ultimo

    errors.add(:rango_inicio, "tiene que ser mayor que el último número ya emitido (#{ultimo})")
  end

  def ficticia_fuera_de_produccion
    return unless ficticia? && Fiscal.produccion?

    errors.add(:ficticia, "no se acepta en producción: ahí solo se emite con un CAI real")
  end

  def intocable_si_ya_se_emitio
    return unless (changed - %w[updated_at]).any? && documentos_emitidos?

    errors.add(:base, "Ya se emitieron documentos con esta autorización: no se puede cambiar")
  end

  def no_borrar_si_ya_se_emitio
    return unless documentos_emitidos?

    errors.add(:base, "Ya se emitieron documentos con esta autorización: no se puede borrar")
    throw :abort
  end
end
