class Manifiesto < ApplicationRecord
  has_paper_trail  # PR-D1.a: audit log

  belongs_to :empresa_manifiesto, optional: true
  belongs_to :sucursal_origen, class_name: "Sucursal", optional: true  # PR-D1.d
  belongs_to :user, optional: true
  has_many :paquetes, dependent: :nullify
  has_many :pre_facturas, dependent: :nullify   # C21-10

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

  # `A7-07` · Dos manifiestos, mismo comportamiento.
  #
  # Yusef: *"es el de envío nacional, de una sucursal a la otra. Lleva un
  # **manifiesto interno** y es igualito."* Igualito en cómo se opera —se arma, se
  # cierra, se recibe escaneando—, distinto en qué lleva: el interno no cruza
  # aduana, así que no tiene consignatario, ni empresa proveedora, ni guía, ni
  # fecha de aduana. Mueve el ~20% de la carga (*"el 80% se queda en San Pedro"*).
  enum :tipo, {
    oficial: "oficial",
    interno: "interno"
  }, prefix: true

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
  # `A7-07` · En el interno la sucursal de entrega **es** el envío: sin ella no
  # se sabe a dónde va el camión. En el oficial sigue siendo opcional, que es
  # como estaba.
  validates :sucursal_entrega, presence: true, if: :tipo_interno?

  # RP-59 · «Expedido por» lo llena el sistema, no el operario.
  #
  # Yusef preguntó él mismo qué iba en ese campo —*"no sé si ponerle las
  # iniciales, la firma, el nombre… solamente quien lo hizo"*— y Jorge decidió
  # el 2026-09-02: **las iniciales de quien lo creó**. Son las que define un
  # admin (`users.iniciales`), que existen porque *"hay nombres repetidos como
  # Juan"*.
  #
  # **Se estampa al crear y no se recalcula.** Es un documento que va firmado y
  # sellado: si mañana el admin le cambia las iniciales a alguien, el manifiesto
  # de la semana pasada tiene que seguir diciendo lo que decía cuando se emitió.
  # Por eso vive en la columna y no en un método que mire al usuario cada vez.
  before_create :estampar_expedido_por

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

  # PR-M8 / C21-10. Los manifiestos que todavía tienen carga sin facturar.
  # Se deriva de los paquetes, no del estado del manifiesto: así la lista se
  # vacía sola a medida que se factura, sin tener que adivinar en qué estado
  # lo dejó `RecibirManifiesto#finalizar!`.
  scope :con_carga_por_facturar, -> {
    joins(:paquetes).merge(Paquete.facturables).distinct.order(numero: :desc)
  }

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

  # Quiénes son «Miami» para el manifiesto: los que lo arman.
  ROLES_DE_MIAMI = %w[supervisor_miami digitador_miami].freeze

  # Y quién abre el candado de uno ya cerrado. Yusef: *"solo los que están en
  # Miami; lo hace normalmente Julien, el supervisor. Tendrían que ser dos de
  # ellos mínimo: el supervisor de Miami y… es que es un etiquetador el otro"* —
  # la frase quedó a medias y se le preguntó cuál era el segundo:
  #
  #   > **2026-08-30: "por hoy solo será supervisor Miami."**
  #
  # Así que la lista es de uno: el digitador arma manifiestos, pero **no puede
  # reabrir uno cerrado**.
  ROLES_QUE_ABREN_EL_CANDADO = %w[admin supervisor_miami].freeze

  def bloqueado?
    !creado?
  end

  # ¿Este usuario puede reabrir un manifiesto ya cerrado?
  #
  # Desde `PR-U1` esto es **solo el candado**: quién entra a `/manifiestos` lo
  # decide `can_access?(:manifiestos)`, que volvió a ser de Miami, y lo que llena
  # San Pedro tiene su propia pantalla. Ya no hay que preguntarse si el usuario
  # es de Miami acá adentro.
  def editable_por?(user)
    return true unless bloqueado?

    user&.tiene_rol?(ROLES_QUE_ABREN_EL_CANDADO)
  end

  # C21-02 · Lo que la pantalla de San Pedro tiene para trabajar: la carga que ya
  # salió de Miami y todavía no tiene su guía del proveedor **o** su fecha de
  # recibido en Honduras.
  #
  # Se deriva de los datos y no del estado: un manifiesto se queda en la lista
  # hasta que efectivamente le pusieron las dos cosas, sin importar en qué punto
  # del recorrido esté.
  # `where.not(id: subconsulta)` y no `where.missing(:guias)`: `missing` agrega un
  # LEFT JOIN y `.or` rechaza dos relations que no son estructuralmente iguales.
  # La subconsulta es segura porque `manifiesto_guias.manifiesto_id` es NOT NULL.
  # `A7-07` · **Solo los oficiales.** La guía del proveedor y la fecha de aduana
  # son de la carga que cruza aduana; un manifiesto interno no las tiene y no las
  # va a tener nunca. Sin el filtro, cada envío de SPS a Tegucigalpa aparecería
  # en `/guias-y-aduana` como «le falta la guía» y no se iría nunca de la lista.
  scope :esperando_datos_de_san_pedro, -> {
    salidos = tipo_oficial.where(estado: %w[enviado en_aduana recibido])
    salidos.where(fecha_aduana: nil)
           .or(salidos.where.not(id: ManifiestoGuia.select(:manifiesto_id)))
  }

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
  # `RP-46` · **El código completo de la sucursal, no su primera letra.**
  #
  # Nació como `M<letra><año><correlativo>` —`MM2026000001` para Miami— y eso
  # funcionaba mientras Miami fuera la única que armaba manifiestos. Con dos
  # sucursales cuyo código empieza igual, **el segundo manifiesto no se puede
  # crear**: `SPS` y `SAM` generan los dos `MS2026000001` y la validación de
  # unicidad lo rechaza. Y el reintento de `save` no lo salva — escucha
  # `RecordNotUnique`, el error de la base, y acá la validación dispara antes.
  #
  # No era teórico: `SPS` (Zerón) y `SAM` (San Manuel) existen las dos hoy. Lo
  # que lo despierta es el **manifiesto interno de sucursal**, que es de lo que
  # se trata construir ahora — hasta hoy nadie más que Miami numeraba.
  #
  # Jorge eligió el código completo (2026-09-01). Cambiaba el formato que Yusef
  # había confirmado (`MM2026000001` → `MMIA2026000001`, dos caracteres más en
  # la hoja impresa), y **se le contó y lo aceptó** al día siguiente: *"le
  # agregué tres caracteres más"* · *"No, está bien"* (`C23`, `RP-46`).
  #
  # Los manifiestos ya numerados **no se renumeran**: su número es como se los
  # conoce, y el contador por sucursal sigue donde estaba.
  def generate_numero
    if sucursal_origen.present?
      codigo = sucursal_origen.codigo.to_s.upcase.presence || "XXX"
      anio = (fecha_enviado&.year || created_at&.year || Time.zone.now.year)
      next_number = ManifiestoCounter.next_for!(sucursal: sucursal_origen, anio: anio)
      self.numero = format("M%<codigo>s%<anio>04d%<num>06d", codigo: codigo, anio: anio, num: next_number)
    else
      # Fallback legacy
      next_number = (self.class.where("numero LIKE 'MA-%'").maximum(Arel.sql("CAST(SUBSTRING(numero FROM 4) AS INTEGER)")) || 0) + 1
      self.numero = "MA-#{next_number.to_s.rjust(6, '0')}"
    end
  end

  # RP-59 · Las iniciales de quien lo creó, congeladas al crear.
  #
  # `iniciales_display` es el que respeta la columna que llena el admin y cae
  # al nombre cuando está vacía. Si el manifiesto se crea sin usuario —consola,
  # una migración de datos— se queda en nil y el papel imprime «—», que es
  # honesto: nadie lo expidió.
  def estampar_expedido_por
    return if expedido_por.present?

    self.expedido_por = user&.iniciales_display
  end
end
