class Sucursal < ApplicationRecord
  has_paper_trail  # PR-D7: audit log de cambios al catálogo
  self.table_name = "sucursales"

  UBICACIONES = %w[miami honduras otros].freeze

  has_many :paquetes, dependent: :restrict_with_error
  has_many :sub_localidades, dependent: :destroy  # PR-D1.c: bodegas internas

  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :nombre, presence: true
  # Obsoleto desde RP-17: el número de recepción es `R<codigo>AAMM000001`
  # (`Paquete#generate_numero_recepcion`) y el prefijo no lo lee nadie. La
  # columna se queda por las filas viejas; el form ya no lo pide (seguimiento de
  # C18-02, 2026-08-27: crear DF México no puede exigir inventar un prefijo).
  validates :codigo_recepcion_prefix, uniqueness: { case_sensitive: false, allow_nil: true },
            format: { with: /\A[A-Z]{1,4}\z/, message: "solo mayusculas (1-4 letras)", allow_blank: true }
  # PR-D3.b: codigo_ep nullable pero único cuando presente. 3 letras
  # exactas (Yusef pattern: SMI, SZR, SHU). Sólo se usa para sucursales
  # que pueden recibir paquetes ENTREGA PERSONAL — no es obligatorio.
  validates :codigo_ep, uniqueness: { case_sensitive: false, allow_nil: true },
                         format: { with: /\A[A-Z]{3}\z/, message: "deben ser 3 letras mayúsculas" },
                         allow_nil: true
  validates :ubicacion, inclusion: { in: UBICACIONES, allow_nil: true }

  normalizes :codigo, with: ->(c) { c.to_s.strip.upcase }
  normalizes :codigo_recepcion_prefix, with: ->(p) { p.to_s.strip.upcase.presence }

  # Solo una es la de recepción por defecto: marcar una desmarca la otra.
  after_save :desmarcar_otras_recepcion_por_defecto,
             if: -> { recepcion_por_defecto? && saved_change_to_recepcion_por_defecto? }
  normalizes :codigo_ep, with: ->(c) { c.to_s.strip.upcase.presence }

  scope :activas, -> { where(activo: true) }
  scope :ordered, -> { order(:nombre) }
  # C18-02: dónde se **recibe** carga, que no es dónde se entrega. Yusef: *"en
  # este momento solo es Miami; futuramente Los Ángeles, Panamá, México"*. Es
  # un checkbox en /sucursales y no una regla escondida en un controller
  # (`ubicacion != honduras` habría dejado afuera a México, que es `otros`).
  # Lo usan el chooser de /etiquetar y /entrega_personal — las dos, el mismo.
  scope :de_recepcion, -> { activas.where(recibe_carga: true).ordered }
  # Las que pueden generar tracking de Entrega Personal (EP-AÑO-SUC-…).
  scope :con_codigo_ep, -> { where.not(codigo_ep: [ nil, "" ]) }
  # Dónde **retira** un cliente: las que no reciben carga. Las dos condiciones a
  # propósito: si a Miami nadie le marcó «recibe carga» (un seed viejo), igual
  # no sale — *"nadie retira allá, es donde se recibe"*. Y una México que
  # recibe tampoco es un lugar de retiro (seguimiento de C18-02).
  scope :de_retiro, -> { activas.where(recibe_carga: false).where.not(ubicacion: "miami").ordered }

  # Dónde recibe este usuario si no eligió: su sucursal, la marcada por defecto,
  # la de su ubicación, la primera. El orden por nombre **nunca** decide — con
  # «DF México» y «Miami», el admin de Honduras veía México preseleccionada
  # (Jorge, 2026-08-27). Lo comparten /etiquetar y /entrega_personal: son
  # gemelas, y la regla vive acá para que no se separen.
  def self.recepcion_por_defecto_para(user, entre: de_recepcion)
    entre = entre.to_a
    return nil if entre.empty?

    entre.find { |s| s.id == user&.sucursal_id } ||
      entre.find(&:recepcion_por_defecto?) ||
      entre.find { |s| s.ubicacion == user&.ubicacion } ||
      entre.first
  end

  def to_s
    nombre
  end

  private

  # Con `update!` y no `update_all`: la que deja de ser la de por defecto
  # también queda en el audit log (paper_trail no ve un `update_all`).
  def desmarcar_otras_recepcion_por_defecto
    self.class.where.not(id: id).where(recepcion_por_defecto: true).find_each do |otra|
      otra.update!(recepcion_por_defecto: false)
    end
  end
end
