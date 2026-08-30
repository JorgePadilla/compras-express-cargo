class Manifiesto < ApplicationRecord
  has_paper_trail  # PR-D1.a: audit log

  belongs_to :empresa_manifiesto, optional: true
  belongs_to :sucursal_origen, class_name: "Sucursal", optional: true  # PR-D1.d
  belongs_to :user, optional: true
  has_many :paquetes, dependent: :nullify

  # C21-02 · El encabezado que Yusef anotó a mano, campo por campo.
  belongs_to :consignatario, optional: true
  belongs_to :tipo_envio_proveedor, optional: true
  # C21-03 · *"Le va a preguntar sucursal, ¿sucursal a entregar?… ahorita
  # tenemos Tegu[cigalpa], SPS"*. A dónde llega la carga en Honduras.
  belongs_to :sucursal_entrega, class_name: "Sucursal", optional: true

  # C21-03 · Los tipos de envío **nuestros** que van adentro, en selección
  # múltiple: *"a veces combinás todo y lo mandás"*. No confundir con
  # `tipo_envio_proveedor`, que es el servicio del proveedor.
  has_many :manifiesto_tipo_envios, dependent: :destroy
  has_many :tipo_envios, through: :manifiesto_tipo_envios

  # C21-04 · Las casas que se arman en Miami. De ellas cuelgan la etiqueta 4×6,
  # el escaneo al empacar y el escaneo al recibir en Honduras.
  has_many :cajas, -> { ordenadas }, class_name: "CajaManifiesto",
           dependent: :destroy, inverse_of: :manifiesto

  # C21-11 · *"El número de guía termina siendo varios"* — y con la forma de
  # nuestros splits: `286441-1`, `-2`, `-3`.
  has_many :guias, -> { order(:position, :id) },
           class_name: "ManifiestoGuia", dependent: :destroy, inverse_of: :manifiesto
  accepts_nested_attributes_for :guias, allow_destroy: true,
                                reject_if: ->(a) { a[:numero].blank? }

  enum :estado, {
    creado: "creado",
    enviado: "enviado",
    en_aduana: "en_aduana",
    recibido: "recibido"
  }

  validates :numero, presence: true, uniqueness: { case_sensitive: false }
  validates :estado, presence: true
  # C21-03, con sus palabras: *"no puede ser sin ninguno, tiene que llevar uno
  # mínimo"*. Es lo que decide qué paquetes salen al finalizar, así que un
  # manifiesto sin ningún tipo no tendría a quién mandar.
  validate :al_menos_un_tipo_de_envio_nuestro

  scope :activos, -> { where(activo: true) }
  # C21-11: las guías se mudaron a su propia tabla. Sin el `left_joins` la
  # búsqueda dejaría de encontrar manifiestos por guía **en silencio**, que es
  # justo por donde los busca el autocomplete del formulario de paquete.
  scope :buscar, ->(term) {
    left_joins(:guias)
      .where("manifiestos.numero ILIKE :q OR manifiestos.numero_guia ILIKE :q OR manifiesto_guias.numero ILIKE :q",
             q: "%#{sanitize_sql_like(term)}%")
      .distinct
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

  # C21-04 · Con casas armadas, el peso y el volumen salen **de las casas** —
  # que es el reporte por el que el proveedor cobra: *"yo agarro el reporte y
  # ellos me cobran [según] el reporte"*. Sin casas cae a la suma de paquetes,
  # que es como venía, para no cambiarle el número a lo que ya está grabado.
  def recalculate_totals!
    con_cajas = cajas.any?

    update!(
      cantidad_paquetes: paquetes.count,
      cantidad_bultos: cajas.count,
      peso_total: con_cajas ? cajas.sum(:peso) : paquetes.sum(:peso_cobrar),
      volumen_total: con_cajas ? cajas.sum(:volumen) : paquetes.sum(:volumen)
    )
  end

  belongs_to :finalizado_por, class_name: "User", optional: true

  # C21-06 · Finalizar vive en `FinalizarManifiesto`, que mueve los paquetes
  # **uno por uno**. `enviar!` los movía con `update_all` y eso salteaba la
  # bitácora, el `fecha_enviado_by_user_id` y la guarda de tareas abiertas —la
  # deuda que `docs/05` anotó y que `procesos_pdf.rb` decía que se saldaba
  # *"cuando se arme el de manifiestos"*.
  def finalizar!(user: nil)
    raise ArgumentError, "el manifiesto #{numero} ya se finalizó" unless creado?

    FinalizarManifiesto.new(self, user: user).call
  end

  # C21-06 · *"Cuando termino el manifiesto se bloquea… se bloquea para que
  # nadie lo [toque]. Sí es editable, pero tiene el botón de editar."*
  #
  # El candado cubre **lo que llena Miami**. Las guías del proveedor y la fecha
  # de recibido en Honduras siguen escribiéndose después de que la carga salió:
  # *"lo ingresan después… le ingresa la encargada de operaciones en San Pedro
  # Sula"* (`C21-02`). Un candado total las dejaría afuera.
  CAMPOS_DE_SAN_PEDRO = %w[fecha_aduana guias_attributes].freeze

  def bloqueado?
    !creado?
  end

  # El tipo de envío del proveedor, para mostrar. Lee las dos formas: la
  # asociación nueva y el varchar viejo de los manifiestos que ya estaban.
  def tipo_envio_del_proveedor
    tipo_envio_proveedor&.nombre.presence || tipo_envio.presence
  end

  # Los tipos NUESTROS que van adentro, en una línea: «CER, CKA».
  def tipos_envio_nuestros
    tipo_envios.map(&:nombre).join(", ")
  end

  # Los números de guía del proveedor, para mostrar. Lee las dos formas: la
  # tabla nueva y el varchar viejo de los manifiestos que ya estaban.
  def numeros_de_guia
    de_la_tabla = guias.map(&:numero)
    return de_la_tabla if de_la_tabla.any?

    [ numero_guia ].compact_blank
  end

  private

  def al_menos_un_tipo_de_envio_nuestro
    return if manifiesto_tipo_envios.reject(&:marked_for_destruction?).any?

    errors.add(:tipo_envios, "hay que elegir al menos un tipo de envío nuestro")
  end

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
