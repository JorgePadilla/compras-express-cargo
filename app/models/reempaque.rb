class Reempaque < ApplicationRecord
  DIVISOR_VOLUMETRICO = 166.0

  belongs_to :paquete
  belongs_to :hecho_por, class_name: "User", optional: true
  belongs_to :tarea, optional: true

  validates :alto_despues, :largo_despues, :ancho_despues, :peso_despues,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :snapshot_dimensiones_antes, on: :create
  before_validation :set_realizado_en, on: :create
  after_create :apply_dimensiones_a_paquete
  after_create :completar_tarea_vinculada

  def peso_volumetrico_antes
    calcular_volumetrico(alto_antes, largo_antes, ancho_antes)
  end

  def peso_volumetrico_despues
    calcular_volumetrico(alto_despues, largo_despues, ancho_despues)
  end

  # Ahorro en peso volumetrico (libras). Positivo = se redujo.
  def ahorro_volumetrico
    return 0 unless peso_volumetrico_antes && peso_volumetrico_despues
    (peso_volumetrico_antes - peso_volumetrico_despues).round(2)
  end

  # Peso a cobrar antes/despues (max entre real y volumetrico). Util para
  # mostrar el impacto real al cliente.
  def peso_cobrar_antes
    [ peso_antes || 0, peso_volumetrico_antes || 0 ].max
  end

  def peso_cobrar_despues
    [ peso_despues || 0, peso_volumetrico_despues || 0 ].max
  end

  def ahorro_peso_cobrar
    (peso_cobrar_antes - peso_cobrar_despues).round(2)
  end

  private

  def calcular_volumetrico(alto, largo, ancho)
    return nil unless alto && largo && ancho
    (alto.to_f * largo.to_f * ancho.to_f / DIVISOR_VOLUMETRICO).round(2)
  end

  def snapshot_dimensiones_antes
    self.alto_antes  ||= paquete.alto
    self.largo_antes ||= paquete.largo
    self.ancho_antes ||= paquete.ancho
    self.peso_antes  ||= paquete.peso
  end

  def set_realizado_en
    self.realizado_en ||= Time.current
  end

  def apply_dimensiones_a_paquete
    # Los before_save callbacks de Paquete recalculan peso_volumetrico y peso_cobrar.
    paquete.update!(
      alto: alto_despues,
      largo: largo_despues,
      ancho: ancho_despues,
      peso: peso_despues
    )
  end

  def completar_tarea_vinculada
    return unless tarea
    return if tarea.realizada?
    tarea.completar!(hecho_por)
  end
end
