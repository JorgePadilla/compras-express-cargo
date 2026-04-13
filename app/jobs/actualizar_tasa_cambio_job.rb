class ActualizarTasaCambioJob < ApplicationJob
  queue_as :default

  def perform
    uri = URI("https://www.floatrates.com/daily/usd.json")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      http.get(uri.request_uri)
    end
    data = JSON.parse(response.body)
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
