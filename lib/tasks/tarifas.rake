namespace :tarifas do
  desc "Siembra la tabla de precios PROPUESTA 2026 (hoja de Yusef). Idempotente."
  task sembrar_propuesta_2026: :environment do
    puts "Sembrando tarifas PROPUESTA 2026..."
    TarifasPropuesta2026.sembrar!(verbose: true)
  end

  desc "Siembra los cargos que NO son flete de la hoja de Yusef, solo los que no tienen ambiguedad."
  task sembrar_cargos_2026: :environment do
    puts "Sembrando cargos PROPUESTA 2026..."
    ServiciosExtraPropuesta2026.sembrar!(verbose: true)
  end
end
