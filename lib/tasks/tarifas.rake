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

  # El seed usa `find_or_create_by!`, asi que corregir `db/seeds.rb` no toca la
  # fila donde el cargo YA existe — que es justamente donde importa. Esta tarea
  # esta suelta por si hay que correr solo la correccion; `sembrar_cargos_2026`
  # ya la incluye.
  desc "Corrige el cambio de servicio a L.100 (Yusef 2026-08-08). Estaba en $15."
  task corregir_cambio_servicio: :environment do
    puts "Corrigiendo cambio de servicio..."
    r = ServiciosExtraPropuesta2026.corregir_cambio_servicio!(verbose: true)
    puts "  · sin cambios (#{r[:motivo]})" unless r[:corregido]
  end
end
