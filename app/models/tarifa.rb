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
  def self.resolver(tipo_envio:, peso:, cliente: nil, proveedor: nil, sucursal: nil)
    return nil if tipo_envio.nil?

    base = activas.para_peso(peso).where(tipo_envio_id: tipo_envio.id)

    niveles = [
      (cliente    && { cliente_id: cliente.id }),
      (proveedor  && { proveedor_id: proveedor.id, cliente_id: nil }),
      (cliente&.categoria_precio_id && { categoria_precio_id: cliente.categoria_precio_id,
                                         cliente_id: nil, proveedor_id: nil }),
      { cliente_id: nil, proveedor_id: nil, categoria_precio_id: nil }
    ].compact

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

  def nivel
    return "Cliente"    if cliente_id.present?
    return "Proveedor"  if proveedor_id.present?
    return "Categoría"  if categoria_precio_id.present?
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
  TOLERANCIA_LIBRAS = Rational(9, 100)

  # Redondea HACIA ARRIBA al múltiplo del incremento, perdonando la tolerancia.
  # nil = sin redondeo, que es el comportamiento histórico y el default.
  #
  # **Esto era un `ceil` puro y cobraba de más.** Un ceil no tiene tolerancia,
  # así que fallaba en dos bandas — y siempre hacia arriba:
  #
  #   | peso | ceil puro | Yusef |
  #   |------|-----------|-------|
  #   | 1.05 | 1.5       | 1.0   |
  #   | 1.09 | 1.5       | 1.0   |
  #   | 1.55 | 2.0       | 1.5   |
  #   | 1.59 | 2.0       | 1.5   |
  #
  # Estaba latente porque `incremento_libras` viene en `nil` en las 58 tarifas
  # cargadas. Muerde el día que Yusef active el escalonado — y lo va a activar
  # él mismo, porque los precios los carga su equipo.
  #
  # ⚠️ La tolerancia es **fija en 0.09**, que es la lectura literal del audio.
  # Yusef describió la regla solo para incrementos de **media libra**; si algún
  # día crea una tarifa con incremento de 1 lb, hay que preguntarle si la
  # tolerancia sigue siendo 0.09 o es proporcional. Está como pregunta ALTA en
  # `docs/entregables/preguntas_para_yusef.xlsx`.
  def redondear_al_incremento(peso)
    inc = incremento_libras.to_d
    return peso if incremento_libras.blank? || inc <= 0

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
end
