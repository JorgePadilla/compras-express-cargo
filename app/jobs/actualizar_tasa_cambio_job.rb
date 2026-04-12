class ActualizarTasaCambioJob < ApplicationJob
  queue_as :default

  def perform
    response = Net::HTTP.get(URI("https://www.floatrates.com/daily/usd.json"))
    data = JSON.parse(response)
    rate = data.dig("hnl", "rate")

    if rate.present? && rate.to_f > 0
      Configuracion.set("tasa_cambio", rate.to_s, tipo: "decimal", categoria: "moneda")
      Rails.logger.info "[TasaCambio] Actualizada a #{rate} LPS/USD"
    else
      Rails.logger.warn "[TasaCambio] No se pudo obtener la tasa HNL desde FloatRates"
    end
  rescue => e
    Rails.logger.error "[TasaCambio] Error: #{e.message}"
  end
end
