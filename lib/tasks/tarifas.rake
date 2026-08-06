namespace :tarifas do
  desc "Siembra la tabla de precios PROPUESTA 2026 (hoja de Yusef). Idempotente."
  task sembrar_propuesta_2026: :environment do
    puts "Sembrando tarifas PROPUESTA 2026..."
    TarifasPropuesta2026.sembrar!(verbose: true)
  end
end
