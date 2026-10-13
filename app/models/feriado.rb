# C31-11 · Los feriados de Honduras, para contar la «posible fecha de entrega»
# en días hábiles (`FechaDeEntrega`).
#
# Los carga el equipo de Yusef, no el código: *"Vamos a tener que hacer un
# portal para que vos metas los feriados." — "Sí… una vez ya quedan grabados.
# Bueno, se pueden modificar… porque cambian la semana morazánica, la semana
# santa."* Por eso es un CRUD (/feriados) y no una lista sembrada.
class Feriado < ApplicationRecord
  has_paper_trail

  validates :fecha, presence: true, uniqueness: { message: "ya tiene un feriado cargado" }
  validates :nombre, presence: true

  scope :ordenados, -> { order(:fecha) }
  scope :desde_hoy, -> { where(fecha: Time.zone.today..) }

  def to_s
    nombre
  end
end
