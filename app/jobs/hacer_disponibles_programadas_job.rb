# PR-P.2 · El barrido de cada minuto del disponible programado
# (`HacerDisponibles`). Corre desde `config/recurring.yml`.
#
# Si el worker estuvo caído a las 7:30, el primer barrido al volver se pone al
# día: busca todo lo que tiene `notificar_at` en el pasado y no avisó, no solo
# lo del último minuto. `/signos_vitales` muestra la tarea y sus fallas.
class HacerDisponiblesProgramadasJob < ApplicationJob
  queue_as :default

  def perform
    HacerDisponibles.call
    # C34-08 · Y los internos recibidos cuya hora de aviso ya llegó.
    NotificarLlegadaASucursal.barrer
  end
end
