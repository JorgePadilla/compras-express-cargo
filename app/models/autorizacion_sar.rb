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
  validate :fechas_en_orden
  validate :punto_activo, on: :create
  validate :sin_solapar
  validate :arriba_de_lo_emitido
  validate :ficticia_fuera_de_produccion
  validate :intocable_si_ya_se_emitio, on: :update

  before_destroy :no_borrar_si_ya_se_emitio
  # PR-F1.2 · En la misma transacción del alta: un rango que no arranca en el
  # número que sigue sube el correlativo (ver `Fiscal::Sequence`). Así lo hacen
  # igual la pantalla, la migración de staging, los seeds y la gema.
  after_create { Fiscal::Sequence.new.alinear_si_hace_falta(self) }
  # PR-F1.4 · Y al corregir el rango de una que todavía no se usó (es la única
  # que se puede editar): el contador se vuelve a calcular desde lo emitido de
  # verdad, para arriba o para abajo. Si cambió de punto o de tipo, en los dos.
  after_update :realinear_correlativo, if: -> { (saved_changes.keys & CAMPOS_DEL_RANGO).any? }

  CAMPOS_DEL_RANGO = %w[punto_de_emision_id tipo_documento rango_inicio rango_fin fecha_limite_emision].freeze

  scope :del, ->(punto, tipo) { where(punto_de_emision: punto, tipo_documento: tipo.to_s) }
  scope :reales, -> { where(ficticia: false) }
  # Con las que se puede emitir: en producción, las ficticias no cuentan (F1.5
  # no las crea ahí, pero esto no depende de eso).
  scope :usables, -> { Fiscal.produccion? ? reales : all }

  # `EEE-PPP-TT`, la llave de la gema.
  def identificador
    punto_de_emision.identificador(tipo_documento)
  end

  def capacidad
    rango_fin - rango_inicio + 1
  end

  # El número completo de 16 dígitos, `EEE-PPP-TT-NNNNNNNN` (Art. 10 num. 7).
  def numero(secuencia)
    "#{identificador}-#{format('%08d', secuencia)}"
  end

  def tipo_nombre
    Fiscal::TIPOS_DE_DOCUMENTO.fetch(tipo_documento, tipo_documento)
  end

  # Cuántos números de este rango ya salieron. `ultimo` se puede pasar ya
  # leído, para que un listado no consulte el correlativo fila por fila.
  def documentos_usados(ultimo = correlativo&.ultimo)
    (ultimo.to_i - rango_inicio + 1).clamp(0, capacidad)
  end

  # Para avisar en la pantalla antes de que se corte la facturación.
  def por_vencer?(al = Fiscal.hoy, dias: 30)
    !vencida?(al) && fecha_limite_emision <= al + dias
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

  # La autorización como la entiende la gema (Art. 10 num. 3-5).
  def to_invoicehn
    Invoicehn::Authorization.new(cai: cai, range_start: numero(rango_inicio), range_end: numero(rango_fin),
                                 limit_date: fecha_limite_emision)
  end

  private

  # QA de PR-F1.3 · La fecha límite no puede ser anterior a la de la
  # autorización: es un error de tipeo, y la pantalla lo guardaba.
  def fechas_en_orden
    return unless fecha_autorizacion && fecha_limite_emision && fecha_limite_emision < fecha_autorizacion

    errors.add(:fecha_limite_emision, "no puede ser anterior a la fecha de autorización")
  end

  # QA de PR-F1.3 · El formulario solo ofrece puntos activos, pero un
  # `punto_de_emision_id` forjado cargaba un CAI en uno desactivado. Solo al
  # crear: desactivar un punto no invalida los CAI que ya tenía.
  def punto_activo
    return if punto_de_emision.nil? || punto_de_emision.activo?

    errors.add(:punto_de_emision, "está desactivado")
  end

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

    # Al crear, contra el contador; al corregir, contra lo emitido de verdad:
    # el contador puede estar alineado a esta misma autorización (PR-F1.4), y
    # bajar su inicio sin documentos emitidos tiene que poder hacerse.
    ultimo = new_record? ? correlativo&.ultimo.to_i : Fiscal::Sequence.ultimo_emitido(punto_de_emision_id, tipo_documento)
    return if rango_inicio > ultimo

    errors.add(:rango_inicio, "tiene que ser mayor que el último número ya emitido (#{ultimo})")
  end

  def realinear_correlativo
    secuencia = Fiscal::Sequence.new
    antes = [ punto_de_emision_id_before_last_save || punto_de_emision_id, tipo_documento_before_last_save || tipo_documento ]
    [ antes, [ punto_de_emision_id, tipo_documento ] ].uniq.each do |punto_id, tipo|
      secuencia.recalcular(PuntoDeEmision.find(punto_id), tipo)
    end
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
