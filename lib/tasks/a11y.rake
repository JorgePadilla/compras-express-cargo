# PR-A11Y.8 · Imprime el presupuesto de axe de cada pantalla, listo para pegar
# en `PRESUPUESTO` de `test/system/accesibilidad_test.rb`. Como
# `botones:presupuesto`: bajar la línea base tiene que costar segundos.
namespace :a11y do
  desc "Inventario de axe por pantalla (hash para PRESUPUESTO)"
  task :presupuesto do
    salida = `AXE_PRESUPUESTO=1 bin/rails test test/system/accesibilidad_test.rb 2>&1`
    lineas = salida.lines.grep(/AXE_PRESUPUESTO/).map { |l| l.sub(/.*AXE_PRESUPUESTO/, "") }.sort
    puts "  PRESUPUESTO = {"
    puts lineas
    puts "  }.freeze"
  end
end
