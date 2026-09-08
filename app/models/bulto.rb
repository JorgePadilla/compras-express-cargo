# C26-19 · Un bulto es **una medición**: lo que el operario armó en la mesa, lo
# que se pesa una sola vez y lo que lleva una sola etiqueta.
#
# Yusef, el 2026-09-07, después de que Jorge le preguntara tres veces:
#
#   "**No es una etiqueta por paquete, es una etiqueta por medición**, y la
#    medición puede tener 100 paquetes."
#
# El bulto es también la **unidad de cobro**: *"le decimos: mire, le valió tanto,
# sale de esto más esto"*. Por eso guarda su propio `peso_cobrar` en vez de
# repartirlo entre sus cajas — ver el comentario de la migración
# `ElBultoDeMedicion`, que explica por qué repartir cobra de más.
class Bulto < ApplicationRecord
  # Cuántas mediciones puede sacar el operario de una sola sesión. Yusef:
  # *"máximo 10 warehouse, máximo 10 etiquetas… el normal de nosotros es 2 a 3;
  # 5 ya es demasiado. Pusimos 10 para no estar ahí «hay que cambiar esto»"*.
  # Y el porqué del techo: *"si hubiéramos metido los 100 bultos, van a estar
  # forzados a no agruparlos"*.
  MAXIMO_POR_SESION = 10

  belongs_to :cliente
  belongs_to :user, optional: true
  has_many :paquetes, dependent: :nullify

  validates :sesion, :medido_at, presence: true
  validates :orden, :de_cuantos, numericality: { greater_than: 0 }

  before_save :calcular_volumetrico
  before_save :calcular_peso_cobrar

  scope :de_la_sesion, ->(sesion) { where(sesion: sesion).order(:orden) }

  # Los hermanos de esta medición — las otras que salieron de la misma mesa.
  def hermanos = Bulto.de_la_sesion(sesion)

  def unico? = de_cuantos.to_i <= 1

  # «1 de 2», que es lo que audita pre-factura: *"cuando ella escanea cualquiera
  # de los QR le dice: ¡eh!, son dos"*.
  def de_cuantos_texto
    return nil if unico?

    "#{orden} de #{de_cuantos}"
  end

  def medidas_texto = [ alto, largo, ancho ].map { |m| m&.to_f }.join("x")

  # Las cajas de este bulto llevan todas el mismo cliente y el mismo servicio
  # —eso lo garantiza `PuedenIrJuntas`—, así que el trato de cobro del cliente
  # se pregunta una sola vez.
  def tipo_envio = paquetes.first&.tipo_envio

  private

  def calcular_volumetrico
    return self.peso_volumetrico = nil if [ alto, largo, ancho ].any?(&:blank?)

    self.peso_volumetrico = VolumetricoCalculator.vlbs(
      VolumetricoCalculator.pulgadas_cubicas(alto, largo, ancho)
    )
  end

  # La misma regla del paquete, sobre los números del bulto. Las excepciones por
  # caja —`cobro_solo_peso`, `cobro_solo_volumetrico`— aplican **solo si las
  # llevan todas**: media excepción no es una excepción, y con una sola caja se
  # comporta igual que hoy.
  def calcular_peso_cobrar
    return if peso.blank? && peso_volumetrico.blank?

    self.peso_cobrar = VolumetricoCalculator.entre_peso_y_vlbs(
      peso || 0, peso_volumetrico || 0,
      solo_volumetrico: solo_volumetrico?,
      solo_peso: solo_peso?
    )
  end

  def cajas = paquetes.loaded? ? paquetes.to_a : paquetes.reload.to_a

  def solo_volumetrico?
    return false if cajas.empty?
    return true if cajas.all?(&:cobro_solo_volumetrico?)

    cliente&.cobra_solo_volumetrico?(cajas.first.tipo_envio_id) || false
  end

  def solo_peso?
    cajas.any? && cajas.all?(&:cobro_solo_peso?)
  end
end
