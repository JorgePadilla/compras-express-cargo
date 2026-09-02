# C21-04 · Una casa del manifiesto — el bulto que se arma en Miami.
#
# Yusef, mostrando la bodega por cámara: *"solo vamos a etiquetar la caja ahí
# empacada"*. Y la pregunta que abrió todo el módulo: *"¿qué otra forma puedo
# hacer para empezar a decir que **estos paquetes van en esa caja**?"*
#
# El tamaño pre-definido es **un punto de partida, no un valor fijo**:
#
#   > "Ellos vienen y marcan EH y le modifican una medida, porque la cortan…
#   >  le decimos «EH cortada»."
#
# Y la medida real importa con plata de por medio:
#
#   > "Tenés que reportarlo a tu proveedor… yo agarro el reporte y **ellos me
#   >  cobran [según] el reporte**."
class CajaManifiesto < ApplicationRecord
  has_paper_trail

  belongs_to :manifiesto
  belongs_to :tamano_caja, optional: true   # nulo = «Especificar», se mide a mano
  belongs_to :user, optional: true
  # C21-07: quién la recibió en Honduras al escanearla.
  belongs_to :recibida_por, class_name: "User", optional: true
  has_many :paquetes, dependent: :nullify

  validates :letra, presence: true, uniqueness: { scope: :manifiesto_id }
  validates :codigo, presence: true, uniqueness: { case_sensitive: false }
  validates :alto, :largo, :ancho, :peso,
            numericality: { greater_than: 0 }, allow_nil: true

  before_validation :copiar_medidas_del_tamano, on: :create
  before_validation :asignar_letra_y_codigo, on: :create
  before_save :calcular_volumen

  scope :ordenadas, -> { order(:id) }

  # El volumen que se le reporta al proveedor: alto × largo × ancho ÷ 166.
  # Es el mismo divisor que ya usa todo el sistema, y da exacto el `595.78` que
  # muestra la pantalla vieja para `46×43×50`.
  def volumen_calculado
    return nil unless alto && largo && ancho

    (VolumetricoCalculator.pulgadas_cubicas(alto, largo, ancho) /
      VolumetricoCalculator::DIVISOR_LB).round(2)
  end

  def medidas
    return nil unless alto && largo && ancho

    format("%gx%gx%g", alto, largo, ancho)
  end

  # C23-01 · El número que acompaña a la letra: `A1`, `B2`, `C3`.
  #
  #   > "Nosotros usamos la A y el 1… el mismo A, A 1, B el 2, C el 3."
  #   > "**Doble** porque la gente, a veces unos leen la A y otros leen el 1."
  #
  # Se **deriva de la letra**, no se guarda. La letra ya sale del contador
  # `ultima_letra`, así que el número es esa misma cuenta escrita de otra forma:
  # una columna aparte podría separarse de ella con un update a mano, y una
  # etiqueta que dijera `B1` sería exactamente la confusión que la doble
  # identificación viene a evitar.
  def numero_bulto
    self.class.numero_para(letra)
  end

  # (B) Los pies cúbicos del bulto, para el público — `C23-03`.
  # El `÷166` de `volumen` es el que le cobra el proveedor y no se toca; este es
  # el otro número, el que la gente entiende.
  def pies_cubicos
    return nil unless alto && largo && ancho

    VolumetricoCalculator.pies_cubicos(
      VolumetricoCalculator.pulgadas_cubicas(alto, largo, ancho)
    )
  end

  # Los tipos de envío que lleva adentro, para la fila y la etiqueta: «CER,CKA».
  def tipos_envio_adentro
    paquetes.filter_map { |p| p.tipo_envio&.nombre }.uniq.sort.join(",")
  end

  private

  def copiar_medidas_del_tamano
    return if tamano_caja.blank?

    self.alto  ||= tamano_caja.alto
    self.largo ||= tamano_caja.largo
    self.ancho ||= tamano_caja.ancho
  end

  # La letra sale del marcador del manifiesto, que **solo sube**. Si saliera de
  # las filas vivas, borrar la última después de imprimir su etiqueta y agregar
  # otra reusaría la letra — y la etiqueta ya pegada al bulto apuntaría a otra
  # caja. Más allá de la Z sigue como las columnas de una hoja de cálculo: Z,
  # AA, AB. Yusef: *"a veces son 50… hemos pegado 20 pico, 30 cajas"*.
  def asignar_letra_y_codigo
    return if letra.present? && codigo.present?

    manifiesto.with_lock do
      siguiente = manifiesto.ultima_letra.to_i + 1
      manifiesto.update_column(:ultima_letra, siguiente)
      self.letra ||= self.class.letra_para(siguiente)
      self.codigo ||= "#{manifiesto.numero}-#{letra}"
    end
  end

  def calcular_volumen
    self.volumen = volumen_calculado
  end

  # 1 → A, 26 → Z, 27 → AA. Igual que una columna de hoja de cálculo.
  def self.letra_para(indice)
    resultado = ""
    n = indice.to_i
    while n.positive?
      n, resto = (n - 1).divmod(26)
      resultado.prepend(("A".ord + resto).chr)
    end
    resultado
  end

  # La vuelta: A → 1, Z → 26, AA → 27. `C23-01`.
  def self.numero_para(letra)
    texto = letra.to_s.strip.upcase
    return nil if texto.empty? || texto.match?(/[^A-Z]/)

    texto.each_char.reduce(0) { |acc, c| acc * 26 + (c.ord - "A".ord + 1) }
  end
end
