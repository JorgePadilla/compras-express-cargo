class RedondeoMediaLibraSiempre < ActiveRecord::Migration[8.0]
  # El redondeo a media libra deja de ser algo que alguien prende.
  #
  # Jorge, cerrando la discusión: *"siempre tuvo que estar los redondeos, no era
  # de prender, era de que siempre tuvo que estar ahí."*
  #
  # Y Yusef ya lo había ordenado el 2026-08-09 al contestar el cuestionario:
  # `RP-03` **"Préndanlo ya"** —sin marcar "primero quiero ver el número"— y
  # `RP-04` **"Todo"**. `PR-C6.20` construyó un botón para activarlo y nadie lo
  # apretó: las tarifas siguieron en `nil`, o sea cobrando el peso exacto de la
  # báscula.
  #
  # La regla, dictada por él en el audio del 2026-08-08: *"El uno punto cero
  # nueve sigue siendo uno. Uno punto uno ya es uno y medio. Y de uno punto seis
  # ya sube."* Está implementada en `Tarifa#redondear_al_incremento` con su
  # tolerancia de 0.09; lo único que faltaba era que se aplicara.
  #
  # ⚠️ **Esto cambia lo que se cobra.** Solo mueve las facturas donde gana el
  # peso de báscula: cuando gana el volumétrico, ese peso ya es múltiplo de 0.5
  # porque `VolumetricoCalculator.half_pound_round` lo garantizó. Por eso el
  # informe de impacto se imprime **antes** de escribir — el log del deploy queda
  # como el registro de cuánto cambió.
  #
  # Lo facturado en el pasado no se toca.
  INCREMENTO = BigDecimal("0.5")

  def up
    informe_de_impacto

    sin_redondeo = Tarifa.where(incremento_libras: nil)
    say "#{sin_redondeo.count} tarifa(s) pasan a cobrar en medias libras."

    # `find_each` + `update!` y no `update_all`: es plata, así que cada fila deja
    # su versión de PaperTrail.
    PaperTrail.request.whodunnit = "migracion 20260813025449 (RP-03/RP-04)"
    sin_redondeo.find_each { |t| t.update!(incremento_libras: INCREMENTO) }

    change_column_default :tarifas, :incremento_libras, from: nil, to: INCREMENTO
    change_column_null    :tarifas, :incremento_libras, false
  ensure
    PaperTrail.request.whodunnit = nil
  end

  def down
    change_column_null    :tarifas, :incremento_libras, true
    change_column_default :tarifas, :incremento_libras, from: INCREMENTO, to: nil
    # A propósito no se vuelve a poner `nil` en las filas: dejar de redondear es
    # una decisión de negocio, no el reverso mecánico de esta migración.
  end

  private

  # Usa el motor real (`Tarifa.resolver` + `cobro_para`), no una reimplementación
  # de la regla — si el informe y la facturación difieren, el informe miente.
  def informe_de_impacto
    return unless defined?(SimuladorRedondeo)

    sim = SimuladorRedondeo.new
    say "Impacto sobre los paquetes cargados:"
    Array(sim.resumen).each do |seg|
      say "#{seg[:segmento]}: #{seg[:paquetes]} paquete(s), delta #{seg[:delta_total]}", true
    end
    say "Delta total: #{sim.total}", true
  rescue StandardError => e
    say "No se pudo calcular el impacto (#{e.class}); se sigue igual.", true
  end
end
