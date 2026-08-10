# PR-C6.35: corre el informe de impacto del redondeo durante el deploy y deja
# el resultado en el log, para no tener que abrir una consola en staging.
#
# **No cambia nada.** Es `SimuladorRedondeo`, que es solo lectura: no escribe,
# no toca `incremento_libras`, no crea documentos. Va como migración porque es
# lo que corre solo al desplegar — Jorge lo pidió así para tener el número sin
# entrar al servidor.
#
# Tres cosas que hay que saber:
#
#   1. **Corre una sola vez.** Para volver a sacarlo hay que usar la tarea:
#      `bin/rails tarifas:simular_redondeo`. Esta migración es una foto del
#      momento del deploy, no un reporte que se pueda repetir.
#   2. **La salida queda en el log del deploy**, entre todo lo demás. Por eso
#      va enmarcada con una línea de `=` — para poder buscarla.
#   3. **Nunca puede tumbar el deploy.** Un informe que rompe una migración
#      sería mucho peor que no tener el informe: deja el deploy a medias. Todo
#      va dentro de un rescue que solo avisa.
class InformeImpactoRedondeo < ActiveRecord::Migration[8.0]
  def up
    say ""
    say "=" * 70
    say "INFORME DE IMPACTO DEL REDONDEO A MEDIA LIBRA (solo lectura)"
    say "=" * 70

    informar
  rescue StandardError => e
    # Explícito: si el informe falla, el deploy sigue. No hay nada que revertir
    # porque no se escribió nada.
    say "No se pudo generar el informe: #{e.class} — #{e.message}"
    say "Se puede correr a mano con: bin/rails tarifas:simular_redondeo"
  end

  # Nada que deshacer: no escribió nada.
  def down; end

  private

  def informar
    sim = SimuladorRedondeo.new
    filas = sim.filas

    if filas.empty?
      say "No hay paquetes con peso a cobrar y tarifa resoluble. Nada que simular."
      return
    end

    say "Paquetes analizados: #{filas.size}"
    say "Tasa de cambio usada: #{CurrencyAware.tasa_vigente.to_f}"
    say "Redondeo activo hoy en: #{Tarifa.where.not(incremento_libras: nil).count} de #{Tarifa.count} tarifas"
    say ""

    sim.resumen.each do |r|
      say r[:segmento]
      say format("  %d paquetes | total L.%+.2f | promedio L.%+.2f",
                 r[:paquetes], r[:delta_total], r[:delta_promedio]), true
      peor = r[:peor_caso]
      say format("  el que mas se mueve: %s  %.2f lb -> %.2f lb  L.%.2f -> L.%.2f",
                 peor.paquete.tracking, peor.peso, peor.peso_redondeado,
                 peor.antes, peor.despues), true
    end

    say ""
    say format("TOTAL sobre los %d paquetes: L.%+.2f  (positivo = se factura mas que hoy)",
               filas.size, sim.total)
    say "=" * 70
  end
end
