# PR-10.a: el motor de precios. Reemplaza la cadena
# `categoria_precio.precio_para(tipo_envio) || tipo_envio.precio_libra`, que
# no sabía de mínimos, escalones ni excepciones.
#
# Spec: docs/05 — Conversación 5 (2026-08-02).
class Tarifa < ApplicationRecord
  has_paper_trail  # los precios afectan lo que se le cobra al cliente

  belongs_to :tipo_envio
  belongs_to :categoria_precio, optional: true
  belongs_to :cliente,          optional: true
  belongs_to :sucursal,         optional: true
  belongs_to :proveedor,        optional: true

  MONEDAS = %w[USD LPS].freeze

  # El formulario manda el **nombre** de la categoría, no su id.
  #
  # La pantalla aparte de categorías se fue en `PR-C7.12` (Jorge: *"no le veo
  # mucho valor"*), así que esta pasó a ser la única forma de crear una — se
  # teclea acá y se crea sobre la marcha. Mismo patrón que el carrier de
  # `/etiquetar` que Yusef aprobó: *"dropdown con texto libre para agregar a la
  # lista"*.
  #
  # Quien resuelve el nombre a id es `ServiciosController`, dentro de una
  # transacción: si la tarifa no pasa validación, la categoría nueva tampoco
  # queda. Acá solo se guarda lo tecleado para que el formulario lo repinte
  # cuando hay error.
  attr_writer :categoria_nombre

  def categoria_nombre
    return @categoria_nombre if defined?(@categoria_nombre)

    categoria_precio&.nombre
  end

  # El precio especial de un cliente se elige por **código**, no por id.
  #
  # Jorge: *"¿se puede hacer lista que sea por código, porque en el sistema no
  # usamos ID?"*. Tenía razón — era un `number_field :cliente_id`, o sea que
  # había que saber que "CEC-002" es internamente el 47, un número que no
  # aparece en ninguna otra pantalla.
  #
  # El campo visible guarda `CÓDIGO — Nombre`, que es lo que escribe
  # `client-autocomplete` al elegir del dropdown.
  attr_writer :cliente_busqueda

  def cliente_busqueda
    return @cliente_busqueda if defined?(@cliente_busqueda)
    return nil unless cliente

    "#{cliente.codigo} — #{cliente.nombre_completo}"
  end

  # Vaciar el campo tiene que **quitar** el precio especial, y no lo hacía.
  #
  # `BusquedaAutocomplete#_elegirEl` solo **escribe** el campo oculto; nunca lo
  # limpia. En `/pre_alertas/new` da igual —el cliente es obligatorio y la
  # pantalla es de alta— pero acá el campo es opcional: si alguien borraba el
  # texto para sacarle el precio especial a una tarifa, el `cliente_id` oculto se
  # quedaba con el valor viejo y **la tarifa seguía siendo de ese cliente**, en
  # silencio.
  #
  # Por eso manda lo que se ve, no lo que llegó oculto.
  before_validation :resolver_cliente_buscado
  validate :cliente_buscado_existe

  validates :precio_libra, numericality: { greater_than_or_equal_to: 0 }
  validates :moneda, inclusion: { in: MONEDAS }
  validates :minimo_moneda, inclusion: { in: MONEDAS }, allow_nil: true
  validates :desde_libras, numericality: { greater_than_or_equal_to: 0 }
  validates :minimo_monto, :minimo_libras,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :incremento_libras, numericality: { greater_than: 0 }, allow_nil: true
  validate  :hasta_mayor_que_desde
  validate  :minimo_monto_requiere_moneda

  scope :activas, -> { where(activo: true) }
  scope :para_peso, ->(peso) {
    where("desde_libras <= :p AND (hasta_libras IS NULL OR hasta_libras > :p)", p: peso.to_d)
  }

  # Devuelve la tarifa aplicable, buscando de lo más específico a lo más
  # general. Yusef: "está el precio normal, precio por ser mayorista/familia,
  # y está el precio especial que está sobre todos los anteriores".
  #
  # Dentro de cada nivel, si hay una fila para la sucursal concreta esa gana
  # sobre la general — "en algunas sucursales hay una pequeña diferencia de
  # precio, costo extra de transporte".
  # `ignorar_precio_del_cliente` salta el primer nivel y deja el resto igual.
  # Contesta *"¿qué pagaría este cliente si no tuviera su precio especial?"*, que
  # es lo que el megacuadro de su ficha necesita para mostrar contra qué se está
  # negociando (`PR-C7.15`). No lo usa nada que cobre: por default es `false` y
  # la cascada es la de siempre.
  def self.resolver(tipo_envio:, peso:, cliente: nil, proveedor: nil, sucursal: nil,
                    ignorar_precio_del_cliente: false)
    return nil if tipo_envio.nil?

    elegida = buscar_para_peso(peso, tipo_envio: tipo_envio, cliente: cliente,
                                     proveedor: proveedor, sucursal: sucursal,
                                     ignorar_precio_del_cliente:)
    return nil if elegida.nil?

    # ── El escalón se elige con el peso que se va a COBRAR ────────────────
    #
    # Antes se elegía con el peso crudo y el precio se aplicaba al redondeado,
    # y eso cobraba de más justo debajo de cada frontera. Un CER de 50.2 lb
    # caía en el tramo `[0, 50.5)` a $4.50, redondeaba a 50.5 y cobraba
    # 50.5 × 4.50 = **$227.25** — cuando la hoja de Yusef dice que 50.5 lb van
    # en el tramo de $4.00, o sea **$202.00**. $25.25 de más, y siempre a
    # nuestro favor porque los tramos de arriba son más baratos por libra.
    #
    # Pasa en toda la banda `(frontera − 0.41, frontera)`: 50.5/100.5/150.5 en
    # CER, y 3.5/13.5/100.5/200.5 en los marítimos. No es un borde raro.
    #
    # Estaba dormido porque `incremento_libras` viene en nil en las 58 tarifas
    # cargadas — se despierta el día que se active el escalonado.
    facturable = elegida.peso_facturable(peso)
    return elegida if facturable == peso.to_d

    # Una segunda pasada, y una sola: el redondeo nunca baja más de la
    # tolerancia y las fronteras son múltiplos del incremento, así que el peso
    # facturable no puede volver a caerse fuera del escalón que le toca.
    buscar_para_peso(facturable, tipo_envio: tipo_envio, cliente: cliente,
                                 proveedor: proveedor, sucursal: sucursal,
                                 ignorar_precio_del_cliente:) || elegida
  end

  # La tarifa aplicable a un peso concreto, sin redondear nada. Es el cuerpo
  # que `resolver` usa en sus dos pasadas.
  def self.buscar_para_peso(peso, tipo_envio:, cliente:, proveedor:, sucursal:,
                            ignorar_precio_del_cliente: false)
    base = activas.para_peso(peso).where(tipo_envio_id: tipo_envio.id)

    # Escrito como appends y no como array + `compact` porque saltarse un nivel
    # con `&&` deja un `false` en el medio, y `compact` solo saca los `nil`.
    niveles = []
    # `cliente&.id` y no `cliente`: un cliente sin guardar no tiene tarifas
    # propias, y filtrar por `cliente_id: nil` no sería "saltarse el nivel" sino
    # matchear cualquier fila de lista, grupo o proveedor — la primera que
    # apareciera. El formulario de alta pinta el cuadro con un `Cliente.new`.
    niveles << { cliente_id: cliente.id } if cliente&.id && !ignorar_precio_del_cliente
    niveles << { proveedor_id: proveedor.id, cliente_id: nil } if proveedor
    if cliente&.categoria_precio_id
      niveles << { categoria_precio_id: cliente.categoria_precio_id,
                   cliente_id: nil, proveedor_id: nil }
    end
    niveles << { cliente_id: nil, proveedor_id: nil, categoria_precio_id: nil }

    niveles.each do |filtro|
      candidatas = base.where(filtro)
      # La fila de la sucursal concreta pisa a la genérica.
      elegida = (sucursal && candidatas.find_by(sucursal_id: sucursal.id)) ||
                candidatas.find_by(sucursal_id: nil)
      return elegida if elegida
    end

    nil
  end

  # Calcula el cobro del flete para un peso dado.
  # Devuelve { subtotal:, moneda:, peso_facturado:, aplico_minimo: }.
  #
  # Ojo con la moneda del resultado: cuando se aplica el mínimo, se devuelve
  # **en la moneda del mínimo**, no en la del precio. Convertirlo acá y que el
  # caller lo vuelva a convertir hacía un round-trip que perdía centavos — un
  # mínimo de L.173.91 sobre una tarifa en USD volvía como L.173.95.
  # El peso por el que esta tarifa va a facturar: el de la báscula redondeado
  # al incremento, con la tolerancia de Yusef (`.10/.60`).
  #
  # Público porque `resolver` lo necesita para elegir el escalón con el peso
  # que se va a cobrar de verdad (PR-C6.18), y el simulador de impacto también.
  #
  # No aplica `minimo_libras`: ese es un piso sobre el **cobro**, no una
  # reclasificación del paquete. Además Yusef lo cerró — "manda el escalonado",
  # sin mínimo en libras — y viene nil en todas las tarifas cargadas.
  def peso_facturable(peso)
    redondear_al_incremento(BigDecimal(peso.to_s))
  end

  def cobro_para(peso_cobrar)
    peso = BigDecimal(peso_cobrar.to_s)
    peso = redondear_al_incremento(peso)
    peso = [ peso, minimo_libras.to_d ].max if minimo_libras.present?

    subtotal = (peso * precio_libra.to_d).round(2, BigDecimal::ROUND_HALF_UP)

    # La comparación sí necesita una moneda común. Si el redondeo de esa
    # conversión mueve el resultado, solo cambia qué rama gana justo en el
    # límite — el monto que se cobra sale sin round-trip.
    piso = minimo_monto_en(moneda)
    if piso && subtotal < piso
      return {
        subtotal: minimo_monto.to_d,
        moneda: minimo_moneda || moneda,
        peso_facturado: peso,
        aplico_minimo: true
      }
    end

    { subtotal: subtotal, moneda: moneda, peso_facturado: peso, aplico_minimo: false }
  end

  # El mínimo se GUARDA sin ISV. Yusef: "L.173.91 más ISV (queda en L.200.00
  # ya con ISV)". Estos dos accessors dejan que el CRUD hable en el idioma de
  # Yusef (200) mientras la columna guarda el neto (173.91).
  def minimo_monto_con_isv
    return nil if minimo_monto.blank?
    (minimo_monto.to_d * (1 + isv_rate)).round(2, BigDecimal::ROUND_HALF_UP)
  end

  def minimo_monto_con_isv=(valor)
    self.minimo_monto = if valor.blank?
      nil
    else
      (BigDecimal(valor.to_s) / (1 + isv_rate)).round(2, BigDecimal::ROUND_HALF_UP)
    end
  end

  def escalon_label
    return "desde #{desde_libras.to_f} lb" if hasta_libras.blank?
    "#{desde_libras.to_f} – #{hasta_libras.to_f} lb"
  end

  # PR-C7.12: el nivel de la categoría se rotula **"Grupo"**, igual que el campo
  # del formulario y la sección de /servicios. Antes decía "Categoría" y la
  # pantalla decía otra cosa: dos nombres para lo mismo es justo lo que Jorge
  # reportó. La tabla se sigue llamando `categoria_precios` — el rótulo cambia,
  # el dato no.
  def nivel
    return "Cliente"    if cliente_id.present?
    return "Proveedor"  if proveedor_id.present?
    return "Grupo"      if categoria_precio_id.present?
    "Lista"
  end

  private

  def isv_rate
    Empresa.instance.isv_rate.to_d
  rescue StandardError
    BigDecimal("0.15")
  end

  # Cuánto se le perdona al peso antes de que suba al siguiente escalón.
  #
  # Yusef, 2026-08-08, dictando la regla:
  #
  #   > "El uno punto cero nueve **sigue siendo uno**. Uno punto uno ya es
  #   >  **uno y medio**. Uno y medio pues uno y medio. Y de **uno punto seis
  #   >  ya sube**."
  #
  # O sea que los umbrales son `.10` y `.60`, no `.01` y `.51`. Hay una
  # tolerancia de 9 centésimas de libra: la báscula tiembla y no se le cobra
  # media libra a alguien por 30 gramos.
  #
  # ⚠️ Sirve **solo para incrementos distintos de media libra**, que es la única
  # rama que quedó usándola. Para media libra —las 44 tarifas cargadas— la regla
  # vive en `VolumetricoCalculator.redondear_media_libra`; ver abajo por qué.
  TOLERANCIA_LIBRAS = Rational(9, 100)

  # Redondea el peso al múltiplo del incremento. nil = sin redondeo.
  #
  # **La media libra delega; no reimplementa.** Hasta `PR-C7.11` esto hacía su
  # propia aritmética —restar `TOLERANCIA_LIBRAS` y `ceil`— y no daba lo mismo
  # que el volumétrico. Coincidían en todo peso de **dos** decimales, que es lo
  # único que barría `redondeo_media_libra_coincide_test`, pero restar 0.09 no
  # es lo mismo que "por debajo de .10" y en el tercero se separaban:
  #
  #   | peso  | esto (antes) | volumétrico | hoja de Yusef |
  #   |-------|--------------|-------------|---------------|
  #   | 3.099 | 3.5          | 3.0         | **3**         |
  #   | 3.599 | 4.0          | 3.5         | **3.50**      |
  #
  # La hoja que Yusef mandó el 2026-08-12 escribe esos dos valores, así que la
  # buena era la del volumétrico. Era latente mientras `incremento_libras` venía
  # en nil; `PR-C7.10` lo puso en 0.5 en las 44 tarifas y quedó vivo — los pesos
  # guardados son `numeric(10,2)`, pero `/cotizador` pasa `params[:peso]` crudo,
  # así que cotizar 3.099 lb cobraba por 3.5.
  #
  # La duplicación entre dos copias "vigiladas por un test" es el bug recurrente
  # de este proyecto. Ahora hay una regla y una implementación.
  #
  # ⚠️ La rama de otros incrementos se queda con el `ceil` y su tolerancia fija
  # de 0.09. Yusef describió la regla **solo para media libra**; si algún día
  # crea una tarifa con incremento de 1 lb, hay que preguntarle si la tolerancia
  # sigue siendo 0.09 o es proporcional. Está como pregunta ALTA en
  # `docs/entregables/preguntas_para_yusef.xlsx`. Hoy no hay ninguna tarifa así.
  def redondear_al_incremento(peso)
    return peso if incremento_libras.blank?

    inc = incremento_libras.to_d
    return peso if inc <= 0
    return VolumetricoCalculator.redondear_media_libra(peso) if inc == BigDecimal("0.5")

    ajustado = peso - TOLERANCIA_LIBRAS
    return BigDecimal("0") if ajustado <= 0

    ((ajustado / inc).ceil * inc).round(2)
  end

  # Convierte el mínimo a la moneda del cobro. Devuelve nil cuando esta
  # tarifa no lleva mínimo de monto o lo tiene desactivado (Exchange/Chain).
  def minimo_monto_en(moneda_destino)
    return nil unless aplica_minimo
    return nil if minimo_monto.blank?

    CurrencyAware.convertir(minimo_monto, de: minimo_moneda || moneda, a: moneda_destino)
  end

  def hasta_mayor_que_desde
    return if hasta_libras.blank? || desde_libras.blank?
    return if hasta_libras.to_d > desde_libras.to_d

    errors.add(:hasta_libras, "debe ser mayor que 'desde'")
  end

  def minimo_monto_requiere_moneda
    return if minimo_monto.blank? || minimo_moneda.present?

    errors.add(:minimo_moneda, "es obligatoria cuando hay un monto mínimo")
  end

  # Reconcilia el cliente con lo que **se ve** en el campo de búsqueda.
  #
  #   texto vacío                  → sin cliente, aunque venga un id oculto
  #   texto + id que le corresponde → ese id, tal cual lo puso el autocomplete
  #   texto sin id (tecleó y no eligió) → se busca por código
  #   código que no existe          → error, nunca un nil silencioso
  #
  # La última es la que importa: dejarlo en nil convertiría un typo en una tarifa
  # de precio de lista, que cobra distinto sin que nadie se entere.
  #
  # El `defined?` distingue "el formulario no mandó el campo" de "lo mandó
  # vacío". Sin eso, cualquier `Tarifa.create!(cliente: x)` de los seeds o los
  # tests se quedaría sin cliente.
  def resolver_cliente_buscado
    return unless defined?(@cliente_busqueda)

    @cliente_no_encontrado = nil
    texto = @cliente_busqueda.to_s.strip

    if texto.blank?
      self.cliente_id = nil
      return
    end

    # `client-autocomplete` deja "CÓDIGO — Nombre"; el código nunca lleva
    # espacios, así que el primer token es el código.
    codigo = texto.split(/\s/).first
    return if cliente && cliente.codigo.to_s.casecmp?(codigo)

    encontrado = Cliente.find_by("LOWER(codigo) = ?", codigo.downcase)

    if encontrado
      self.cliente = encontrado
    else
      self.cliente_id = nil
      @cliente_no_encontrado = codigo
    end
  end

  # A propósito **no** crea el cliente que falta, al revés que `categoria_nombre`:
  # una categoría nueva es un grupo que alguien está inventando ahora, pero un
  # cliente que no está es un error de tipeo.
  def cliente_buscado_existe
    return if @cliente_no_encontrado.blank?

    errors.add(:base, "No existe un cliente con el código \"#{@cliente_no_encontrado}\". " \
                      "Buscalo por código o por nombre y elegilo de la lista.")
  end
end
