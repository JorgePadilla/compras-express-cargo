# C33-03 · El resumen de las 6 de la tarde (`ResumenDeEnviados`). Corre desde
# `config/recurring.yml`, con la hora de Honduras escrita en el schedule.
class ResumenDeEnviadosJob < ApplicationJob
  queue_as :default

  def perform
    ResumenDeEnviados.call
  end
end
