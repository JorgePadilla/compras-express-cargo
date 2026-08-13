namespace :tarifas do
  desc "Siembra la tabla de precios PROPUESTA 2026 (hoja de Yusef). Idempotente."
  task sembrar_propuesta_2026: :environment do
    puts "Sembrando tarifas PROPUESTA 2026..."
    TarifasPropuesta2026.sembrar!(verbose: true)
  end

  desc "Muestra las tarifas de categoria que quedaron del backfill viejo y hoy cobran (A7-25)."
  task huerfanas: :environment do
    hallazgos = TarifasHuerfanas.detectar

    if hallazgos.empty?
      puts "No hay tarifas huerfanas: las de categoria cargadas son todas de la hoja de Yusef."
      next
    end

    puts "#{hallazgos.size} tarifas de categoria que la hoja de precios no declara."
    puts "Estan en el nivel 'categoria', que GANA sobre el precio de lista.\n\n"
    puts format("%-22s %-8s %8s %10s   %s", "CATEGORIA", "SERVICIO", "COBRA", "SIN ELLA", "POR QUE")
    puts "-" * 92

    hallazgos.sort_by { |h| [ h.categoria, h.servicio ] }.each do |h|
      lista = h.precio_si_se_borra ? format("%.2f", h.precio_si_se_borra) : "sin lista"
      puts format("%-22s %-8s %8.2f %10s   %s",
                  h.categoria, h.servicio.upcase, h.precio_actual, lista, h.motivo)
    end

    suben = hallazgos.count { |h| h.precio_si_se_borra && h.precio_si_se_borra > h.precio_actual }
    puts "\nSi se borran, a #{suben} de #{hallazgos.size} les SUBE el precio."
    puts "Correr `rake tarifas:limpiar_huerfanas` para borrarlas."
  end

  desc "Borra las tarifas huerfanas que muestra `tarifas:huerfanas` (A7-25)."
  task limpiar_huerfanas: :environment do
    hallazgos = TarifasHuerfanas.detectar
    if hallazgos.empty?
      puts "Nada que borrar."
      next
    end

    # Una por una y con `destroy`, no `delete_all`: cada fila deja su version de
    # PaperTrail. Es plata — tiene que quedar quien la borro y cuando.
    hallazgos.each do |h|
      puts "borrando #{h.categoria} / #{h.servicio.upcase} (#{h.motivo})"
      h.tarifa.destroy!
    end
    puts "#{hallazgos.size} tarifas borradas."
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

  # PR-C6.19: el numero que se le lleva a Yusef. Solo lectura — no escribe
  # nada ni toca `incremento_libras`. Se corre en STAGING: en local hay 54
  # paquetes de seed y no sirven como evidencia.
  desc "Simula cuanto cambia la facturacion si se prende el cobro en medias libras"
  task simular_redondeo: :environment do
    sim = SimuladorRedondeo.new
    filas = sim.filas

    if filas.empty?
      puts "No hay paquetes con peso a cobrar y tarifa resoluble. Nada que simular."
      next
    end

    puts "SIMULACION DE REDONDEO A MEDIA LIBRA  (solo lectura)"
    puts "Paquetes analizados: #{filas.size}"
    puts "Tasa de cambio usada: #{CurrencyAware.tasa_vigente.to_f}"
    puts ""

    sim.resumen.each do |r|
      puts r[:segmento]
      puts format("  %d paquetes | total L.%+.2f | promedio L.%+.2f",
                  r[:paquetes], r[:delta_total], r[:delta_promedio])
      peor = r[:peor_caso]
      puts format("  el que mas se mueve: %s  %.2f lb -> %.2f lb  L.%.2f -> L.%.2f",
                  peor.paquete.tracking, peor.peso, peor.peso_redondeado,
                  peor.antes, peor.despues)
      puts ""
    end

    puts format("TOTAL sobre los %d paquetes: L.%+.2f", filas.size, sim.total)
    puts "(positivo = se factura mas que hoy)"
  end
end
