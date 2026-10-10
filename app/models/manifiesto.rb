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
  # C29-09 · Editar no puede dejar adentro lo que escanear no deja entrar.
  # Jorge le agregó un tipo a un manifiesto ya armado y anduvo; y Yusef:
  #
  #   > "Pero eso pasa de que ya metiste todo y le cambiaste a otro servicio,
  #   >  y todos los que están adentro… Sí, Jorge, no puede ser."
  #
  # Agregar un tipo está bien. Sacarle uno que tienen paquetes adentro los
  # deja en un manifiesto que no los acepta —el mismo error que el escaneo
  # frena desde `C28-04`, entrando por la puerta de editar—. Y lo mismo con la
  # sucursal de entrega (`C29-07`). `update` asigna y guarda en una sola
  # transacción, así que si esto falla las filas de tipos que la asignación ya
  # tocó vuelven atrás.
  #
  # Solo cuando **eso** cambia: finalizar, recibir y fechar el manifiesto
  # también son `update`, y un paquete que entró con «Omitir» desde `/empacar`
  # (`C21-01`) es de otro tipo a propósito. Lo que se frena es el cambio, no
  # lo que ya estaba.
  validate :no_deja_afuera_lo_que_tiene_adentro, on: :update,
           if: -> { @tipos_cambiados || will_save_change_to_sucursal_entrega_id? }
  after_save { @tipos_cambiados = false }

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
  # Jorge, 2026-09-06 · Y las de quien puso la fecha de recibido en Honduras.
  # Solo cuando la fecha cambia: agregar una guía no toca a quien la recibió.
  before_save :estampar_recibido_hn_por, if: :will_save_change_to_fecha_aduana?
  validate :fecha_aduana_no_es_futura, if: :will_save_change_to_fecha_aduana?

  # PR-C30.14 · El formulario manda **un día** (`2026-10-10`) y la columna
  # guarda **un momento**: la recepción la sella con la hora
  # (`RecibirManifiesto#finalizar!`). Sin esto, guardar /edit sin tocar la
  # fecha la «cambiaba» de las 14:33 a las 00:00, y `estampar_recibido_hn_por`
  # le ponía como «recibido por» las iniciales de quien guardó el encabezado
  # en Miami. El mismo día que ya está no es un cambio.
  def fecha_aduana=(valor)
    return if valor.is_a?(String) && fecha_aduana && valor.strip == fecha_aduana.to_date.iso8601

    super
  end

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
  # Así que la lista era de uno: el digitador arma manifiestos, pero **no puede
  # reabrir uno cerrado**.
  #
  # C30-06 · El 2026-10-09 Yusef lo amplió (audio a1_1119, min 48): *"¿quién
  # puede editar?… supervisores me imagino — exacto, correcto, cuando ya está
  # bloqueado son los supervisores, **Pedro y Miami**"*. No hay un rol «supervisor
  # de San Pedro»: Jorge eligió el 2026-10-10 al de **Pre-Factura**, que es el
  # que trabaja la carga que llega. El digitador y el cajero siguen sin abrirlo.
  ROLES_QUE_ABREN_EL_CANDADO = %w[admin supervisor_miami supervisor_prefactura].freeze

  # Cómo se nombra en los avisos a quien puede abrirlo. Uno solo, para que los
  # mensajes no se queden diciendo «de Miami» cuando la lista cambie.
  QUIEN_ABRE_EL_CANDADO = "un supervisor (Miami o Pre-Factura)".freeze

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

  # ── C30-06 · «Editar» abre el manifiesto entero ───────────────────────
  #
  # Yusef, 2026-10-09, sobre uno ya finalizado: *"hay dos cosas que ocupo [en]
  # el manifiesto: uno, cambiar etiquetas, y dos, eliminar paquetes que no se
  # fueron"* · *"después de finalizado lo necesitamos corregir, porque a veces
  # después de finalizado agregamos algo que se quedaba"*. Y cómo: *"que le
  # demos un botón que diga editar… y ya podemos editarlo todo otra vez, pero
  # que presionen el botón, para que nadie toque algo que no era"* — *"ya nos
  # pasó que venían y sin querer tocaban el manifiesto que ya se había ido"*.
  #
  # El «Editar igual» de C21-06 abría solo el encabezado. Esto abre **lo de
  # adentro**: cajas, paquetes por escaneo, sacar los que no se fueron.
  #
  # Se guarda en el manifiesto (`edicion_abierta_at` / `_por`) y no se decide
  # pedido por pedido, porque el botón se aprieta una vez y después se escanea
  # muchas, y quien abra la ficha mientras tanto tiene que ver que está abierto
  # y quién lo abrió. paper_trail se queda con quién lo abrió y quién lo cerró.
  belongs_to :edicion_abierta_por, class_name: "User", optional: true

  # Cualquier **oficial** ya finalizado: enviado, en aduana o recibido.
  #
  # PR-C30.14 · Hasta acá era solo `enviado?`, y ese límite **lo pusimos
  # nosotros** en C30-06, no Yusef: desde `en_aduana` Honduras ya escanea, y
  # de esos paquetes cuelgan recepción, medición y pre-factura. Jorge, el
  # 2026-10-10, mirando el 21 —recibido— en staging: *"esta pantalla de editar
  # me debería dejar editar todo lo que está en el manifiesto"*.
  #
  # **Confirmado**: Jorge, el 2026-10-10 — *"I already asked this, answer is
  # yes, allow both but only admin and supervisors"*. Es lo que Yusef dijo en el
  # audio del 9 (a1_1119, min 48): *"cuando ya está bloqueado son los
  # supervisores"*. Quiénes, en `ROLES_QUE_ABREN_EL_CANDADO`.
  #
  # Lo que San Pedro ya contó se cuida **paquete por paquete** y no cerrando
  # el manifiesto entero: `sacar!` deja donde está al que ya llegó y no saca al
  # que tiene pre-factura o medición (`NoSeSaca`), y `meter!` manda a aduana
  # al que entra a uno ya recibido.
  #
  # Y sigue siendo solo el **oficial**: es el contenedor de Miami del que habló
  # Yusef; el interno pone otros estados (`enviado_sucursal`, el destino del
  # camión) que esto no sabe deshacer.
  def reabrible?
    bloqueado? && tipo_oficial?
  end

  # Derivado de `reabrible?` a propósito. Hasta PR-C30.14 eso hacía que se
  # cerrara sola cuando Honduras empezaba a recibir (`en_aduana`); ahora que
  # los recibidos también se reabren, **se queda abierta hasta «Cerrar
  # edición»**, que es el botón que Yusef pidió apretar.
  def edicion_abierta?
    edicion_abierta_at.present? && reabrible?
  end

  # ¿Puede este usuario tocar lo de adentro (cajas y paquetes)? Abierto,
  # cualquiera con la sección. Finalizado, solo quien abre el candado y solo con
  # la edición abierta: un digitador no se cuela por la ventana que un
  # supervisor dejó abierta.
  def modificable_por?(user)
    creado? || (edicion_abierta? && editable_por?(user))
  end

  # Por qué no se puede tocar, dicho para quien lo intentó. Vivía en el concern
  # `CandadoDelManifiesto`; bajó acá porque /paquetes también lo tiene que
  # decir (el formulario del paquete reasigna manifiesto) y dos copias del
  # mismo texto se separan.
  def motivo_del_candado
    if !reabrible?
      # PR-C30.14 · Desde que los recibidos se reabren, acá solo llega el
      # interno ya finalizado.
      "#{numero} ya no se puede cambiar: es un manifiesto interno y está #{estado.humanize.downcase}."
    elsif edicion_abierta?
      "#{numero} está abierto para corregir, pero solo #{QUIEN_ABRE_EL_CANDADO} puede cambiarlo."
    else
      "#{numero} está finalizado y bloqueado: para corregirlo, #{QUIEN_ABRE_EL_CANDADO} aprieta «Editar»."
    end
  end

  class NoSePuedeReabrir < StandardError; end

  def abrir_edicion!(user)
    raise NoSePuedeReabrir, "Solo #{QUIEN_ABRE_EL_CANDADO} puede abrir un manifiesto finalizado." unless editable_por?(user)
    unless reabrible?
      raise NoSePuedeReabrir, "#{numero} no se puede abrir: solo se reabren los manifiestos oficiales ya finalizados."
    end

    update!(edicion_abierta_at: Time.current, edicion_abierta_por: user)
  end

  def cerrar_edicion!
    update!(edicion_abierta_at: nil, edicion_abierta_por: nil)
  end

  # El estado al que vuelve un paquete que sale del manifiesto: el mismo que
  # `EmpacarSinEscanear` busca para meterlo. Una sola fuente — antes
  # `remove_paquete` escribía `recibido_miami` a mano, y en el interno eso
  # mandaba a Miami un paquete que estaba disponible en la sucursal.
  def estado_antes_de_salir
    EmpacarSinEscanear.new(self).estado_buscado
  end

  class NoSeSaca < StandardError; end

  # Sacar un paquete: lo que hacía `remove_paquete`, más lo que le faltaba.
  #
  # - Suelta la caja. `mover_paquete` ya lo hacía y `remove_paquete` no: el
  #   paquete fuera del manifiesto seguía contando en la 4×6 de la caja.
  # - En uno finalizado (C30-06, *"eliminar paquetes que no se fueron"*) el
  #   paquete ya estaba en `enviado_honduras`: vuelve con el mismo retroceso que
  #   usa /paquetes (`apply_retroceso_cleanup!`), que limpia la fecha y el
  #   usuario de enviado. Si no viajó, no puede decir que salió.
  #
  # PR-C30.14 · Con los recibidos reabribles (decisión de Jorge, 2026-10-10)
  # hay dos casos más, y los dos cuidan lo que San Pedro ya hizo:
  #
  # - **El que ya llegó** (`llego_a_honduras?`) no vuelve a Miami: se queda en
  #   su estado —está en la aduana, físicamente— y solo pierde el manifiesto y
  #   la caja, con sus fechas de viaje (`conservar_fechas_de_viaje`). Sin
  #   retroceso.
  # - **El que ya tiene pre-factura o medición no sale** (`NoSeSaca`), y no se
  #   deshace nada en cascada: que lo suelte primero quien lo tomó.
  def sacar!(paquete)
    motivo = motivo_para_no_sacar(paquete)
    raise NoSeSaca, motivo if motivo

    if llego_a_honduras?(paquete)
      paquete.conservar_fechas_de_viaje = true
      soltar!(paquete, estado: paquete.estado)
    else
      # El cierre «con faltantes» ya le escribió dónde aterrizó
      # (`mover_a_aduana`), y el retroceso no toca esa columna: volvería a
      # Miami diciendo que está en San Pedro. En Miami la carga del oficial
      # no la lleva (`C23-14`), así que vuelve vacía.
      paquete.sucursal_actual = nil if tipo_oficial? && (en_aduana? || recibido?)
      soltar!(paquete, estado: estado_antes_de_salir)
    end
  end

  # Por qué este paquete no puede salir del manifiesto, o nil. Público porque
  # la pistola de «Eliminar paquetes» lo dice **antes** de intentar
  # (`EscaneoDeManifiesto#para_quitar`), y una regla dicha en dos lugares se
  # separa.
  def motivo_para_no_sacar(paquete)
    codigo = paquete.numero_recepcion_visible.presence || paquete.tracking
    if (pre_factura = pre_factura_vigente_de(paquete))
      "#{codigo} no sale del manifiesto: ya está en la pre-factura #{pre_factura.numero}. Anulala primero."
    elsif paquete.medicion_sesion.present?
      "#{codigo} no sale del manifiesto: ya se midió en San Pedro. Sacalo de su medición primero."
    end
  end

  # ¿Llegó a Honduras? Solo se pregunta en un manifiesto que Honduras ya está
  # recibiendo (`en_aduana`) o recibió; de uno abierto o en camino no llegó
  # nada.
  #
  # Con caja manda **la caja**: llegó si se escaneó al recibir (`recibida_at`).
  # Ojo, a propósito: la caja que no apareció y se cerró «con faltantes» ya
  # movió a sus paquetes a `en_aduana` (`RecibirManifiesto#finalizar!`), y aun
  # así acá cuenta como que **no** llegó y vuelve a Miami. Es lo que pidió
  # Jorge: lo que dice si llegó es la pistola, no el barrido del cierre.
  #
  # Sin caja (el camino sin escaneo) no hay qué escanear, y manda el estado:
  # llegó si ya pasó de `enviado_honduras`. Un estado fuera del recorrido
  # (retenido, consolidando) cuenta como llegado: quedarse donde está es la
  # opción que no deshace nada.
  def llego_a_honduras?(paquete)
    return false unless tipo_oficial? && (en_aduana? || recibido?)
    return paquete.caja_manifiesto.recibida_at.present? if paquete.caja_manifiesto

    !paquete.estado.in?(Paquete::ESTADOS_ORDEN.take(Paquete::ESTADOS_ORDEN.index("en_aduana")))
  end

  # Salir del manifiesto **a un estado que decide otro**. Es la parte común de
  # `sacar!` —que vuelve al estado de antes de salir— y del retroceso de estado
  # de /paquetes, donde el supervisor eligió a qué estado vuelve y eso no se
  # pisa.
  #
  # Antes el retroceso soltaba el manifiesto por su cuenta
  # (`apply_retroceso_cleanup!` ponía `manifiesto_id` en nil) y se quedaba ahí:
  # la caja seguía apuntando al paquete y el manifiesto seguía contándolo. Dos
  # caminos para lo mismo, y uno se había quedado corto. Ahora los dos pasan
  # por acá: suelta la caja, limpia lo de los estados posteriores, deja la
  # bitácora (`update!`, no `update_column`) y recalcula.
  def soltar!(paquete, estado:)
    transaction do
      paquete.apply_retroceso_cleanup!(estado)
      paquete.update!(manifiesto: nil, caja_manifiesto: nil, estado: estado)
      recalculate_totals!
    end
  end

  class NoEntra < StandardError; end

  # Meter un paquete. En uno abierto es lo de siempre; en uno finalizado y
  # reabierto (C30-06) el paquete sale **como los demás** —`enviado_honduras`,
  # con fecha y usuario— por el mismo `FinalizarManifiesto#enviar`, con su
  # misma guarda de tareas: si tiene una pendiente no entra, igual que no
  # habría dejado finalizar.
  #
  # PR-C30.14 · Y en uno que Honduras ya recibió llega **como los demás**: a
  # `en_aduana`, en la sucursal de entrega, por el mismo
  # `RecibirManifiesto#mover_a_aduana` que usa la recepción (una sola manera
  # de aterrizar). Lo mismo si entra a una caja que ya se escaneó al recibir.
  # En uno que se está recibiendo (`en_aduana`) se queda en `enviado_honduras`:
  # llega cuando escaneen su caja, o con el cierre de la recepción si va suelto.
  #
  # `cambios` es lo que cada puerta escribe además del manifiesto (el empaque
  # pone su caja). Va todo en una transacción: un paquete trabado no queda
  # adentro a medias.
  def meter!(paquete, user:, **cambios)
    transaction do
      paquete.update!(manifiesto: self, **cambios)
      if bloqueado?
        problema = FinalizarManifiesto.new(self, user: user).enviar(paquete)
        raise NoEntra, "#{paquete.numero_recepcion_visible} no entró: #{problema}." if problema

        if aterriza_al_entrar?(paquete) && !RecibirManifiesto.new(self, user: user).mover_a_aduana(paquete)
          raise NoEntra, "#{paquete.numero_recepcion_visible} no entró: " \
                         "#{paquete.errors.full_messages.to_sentence.presence || "no pasó a aduana"}."
        end
      end
      recalculate_totals!
    end
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

  # PR-P.4 · C30-15 · Los manifiestos que la hoja de preparación ofrece para
  # pre-facturar. Yusef: *"solo le van a aparecer los que ya fueron
  # recibidos"* — en aduana —, y *"cuando ya entra prefactura y lo
  # seleccionamos y lo terminamos, desaparece de los pendientes"*.
  #
  # **Derivado de los datos, sin estado nuevo** (Fase 14): sale de la lista
  # cuando ya no le queda paquete sin pre-factura de esos servicios. Un paquete
  # cuya caja no llegó (`C28-14`) sigue sin pre-factura, así que el manifiesto
  # con faltantes **se queda**, que es lo que tiene que pasar. Los que ya no
  # viajan (anulado, entregado…) no lo retienen.
  #
  # Solo **oficiales**: el interno no se pre-factura, ya viene facturado.
  ESTADOS_PARA_PRE_FACTURA = %w[en_aduana recibido].freeze

  scope :para_hoja, ->(tipo_envio_ids) {
    pendientes = Paquete.sin_pre_factura_en_manifiesto
                        .where(tipo_envio_id: Array(tipo_envio_ids).compact_blank)
                        .select(:manifiesto_id)
    tipo_oficial.where(estado: ESTADOS_PARA_PRE_FACTURA, activo: true)
                .where(id: pendientes)
                .order(:numero)
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

  # *"Si el tipo de servicio no concuerda con el de la caja, pita"* (`C21-01`).
  # Vivía como `tipo_permitido?` adentro de `EmpaqueController`; desde `C28-04`
  # la usa también el escaneo del manifiesto, y una regla que se escribe dos
  # veces termina diciendo dos cosas.
  def acepta_tipo?(paquete)
    tipo_envio_ids.include?(paquete.tipo_envio_id)
  end

  # C29-09 · `tipo_envio_ids=` de un `has_many :through` no deja rastro en
  # `changes`, así que se anota acá para que la validación sepa que los tipos
  # se tocaron.
  def tipo_envio_ids=(ids)
    @tipos_cambiados = true
    super
  end

  # C29-07 · Y lo mismo con **a dónde va**. Yusef, escaneando en staging el
  # 2026-10-08:
  #
  #   > "Yo marqué que van para San Pedro y van paquetes que van para Humuya, y
  #   >  debería de notificarte."
  #   > "Recordá que la idea es que empaquen las cajas de acuerdo a dónde van."
  #   > "Y que no debería haberme dejado meter paquetes que van para
  #   >  Tegucigalpa… algo similar al tipo de envío, el modal así. Exactamente
  #   >  así."
  #
  # Lo que se compara es la **sucursal de retiro** del paquete (`sucursal`, la
  # que la etiqueta imprime como «RETIRA EN») contra la sucursal de entrega del
  # manifiesto. Un manifiesto sin sucursal de entrega no tiene contra qué
  # comparar y acepta todo, como hasta hoy. Un paquete sin sucursal de retiro
  # tampoco se frena acá: no se sabe a dónde va, y ese dato que falta es su
  # propio problema (`C29-03`), no uno que la pistola pueda resolver.
  #
  # **Solo el oficial.** En el interno la sucursal de entrega es a dónde va el
  # camión, y puede llevar carga que no retira ahí: `CerrarManifiestoInterno`
  # tiene un test que lo dice con todas las letras —*"el destino sale del
  # manifiesto, no de dónde retira el cliente"*—. Yusef hablaba de empacar en
  # Miami.
  def acepta_sucursal?(paquete)
    tipo_interno? || sucursal_entrega_id.nil? || paquete.sucursal_id.nil? ||
      paquete.sucursal_id == sucursal_entrega_id
  end

  # Los números de guía del proveedor, para mostrar. Lee las dos formas: la
  # tabla nueva y el varchar viejo de los manifiestos que ya estaban.
  # C26-17 · El match con lo que Miami dijo que mandó, para el panel de la
  # estación de medición: *"que aparezcan los que faltan de ese manifiesto, así
  # como match con lo que se mandó desde Miami"*.
  #
  # `enviados` son los paquetes del manifiesto que son cajas de verdad (un
  # «esperado» de pre-alerta no viaja). Se cuenta en una sola pasada: la lista
  # de pendientes se arma con los mismos objetos.
  def resumen_de_medicion
    cajas = paquetes.where.not(estado: Paquete::NO_SON_CAJAS).to_a
    medidos = cajas.count { |p| p.medido_at.present? }
    descartados = cajas.count(&:descartado_de_medicion?)

    { enviados: cajas.size, medidos: medidos, descartados: descartados,
      faltan: cajas.size - medidos - descartados }
  end

  def numeros_de_guia
    de_la_tabla = guias.map(&:numero)
    return de_la_tabla if de_la_tabla.any?

    [ numero_guia ].compact_blank
  end

  # Lo que San Pedro tiene que poner, ¿ya está? Decide si el botón de la
  # bandeja dice «Completar» o «Corregir».
  def datos_de_san_pedro_completos?
    fecha_aduana.present? && numeros_de_guia.any?
  end

  private

  # ¿El que entra ya está en Honduras? Si la recepción se cerró, o si su caja
  # ya pasó por la pistola de recibir. Solo el oficial: el interno aterriza en
  # `disponible_entrega`, por su propia recepción.
  def aterriza_al_entrar?(paquete)
    return false unless tipo_oficial?

    recibido? || paquete.caja_manifiesto&.recibida_at.present?
  end

  # La pre-factura que tiene tomado al paquete, si no está anulada. Se mira
  # también por las líneas y no solo por `pre_factura_id`: una línea puede
  # seguir viva apuntando al paquete aunque la FK diga otra cosa.
  def pre_factura_vigente_de(paquete)
    directa = paquete.pre_factura
    return directa if directa && !directa.anulado?

    PreFactura.where.not(estado: "anulado")
              .where(id: PreFacturaItem.where(paquete_id: paquete.id).select(:pre_factura_id))
              .first
  end

  def no_deja_afuera_lo_que_tiene_adentro
    adentro = paquetes.includes(:tipo_envio, :sucursal).to_a
    return if adentro.empty?

    sin_su_tipo = @tipos_cambiados ? adentro.reject { |p| p.tipo_envio_id.nil? || acepta_tipo?(p) } : []
    if sin_su_tipo.any?
      nombres = sin_su_tipo.map { |p| p.tipo_envio.nombre }.uniq.sort.to_sentence
      errors.add(:base, "No se le puede sacar #{nombres}: hay #{sin_su_tipo.size} paquete(s) de ese tipo " \
                       "adentro. Sacalos del manifiesto primero")
    end

    de_otra = will_save_change_to_sucursal_entrega_id? ? adentro.reject { |p| acepta_sucursal?(p) } : []
    if de_otra.any?
      errors.add(:base, "La sucursal de entrega no puede ser #{sucursal_entrega.nombre}: hay #{de_otra.size} paquete(s) adentro " \
                       "que retiran en otra sucursal. Sacalos del manifiesto primero")
    end
  end

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

  # Jorge, 2026-09-06 · Las iniciales de quien puso la fecha de recibido en
  # Honduras — *"a esta vista le faltan las iniciales de quien está haciendo la
  # acción"*. Hermana de `expedido_por`, con **dos diferencias a propósito**,
  # para que nadie las «armonice»:
  #
  # 1. **Se vuelve a sellar cada vez que la fecha cambia.** La respuesta honesta
  #    a «¿quién puso esta fecha?» es quien puso la que está. El congelado de
  #    `RP-59` era contra el admin renombrando iniciales, no contra correcciones.
  # 2. Lee `Current.user`, porque `GuiasAduanaController` no le pasa usuario al
  #    manifiesto (la relación `user` es quien lo armó en Miami).
  #
  # Quién escribió cada guía no se sella acá: eso lo tiene `paper_trail`.
  def estampar_recibido_hn_por
    self.recibido_hn_por = fecha_aduana.present? ? Current.user&.iniciales_display : nil
  end

  # «Recibido en Honduras» es el día en que **nosotros** la recibimos: una fecha
  # futura no es un dato, es un dedo que resbaló. Se valida solo cuando la fecha
  # cambia —había filas con fechas futuras ya guardadas, y sin este guard San
  # Pedro no podría ni agregarles una guía hasta corregirlas.
  def fecha_aduana_no_es_futura
    return if fecha_aduana.blank? || fecha_aduana.to_date <= Date.current

    errors.add(:fecha_aduana, "no puede ser una fecha futura: es el día en que nosotros la recibimos")
  end
end
