# PR-BTN.2: bajar la línea base del lint tiene que costar 10 segundos.
#
# Si actualizar el presupuesto fuera a mano, nadie lo haría y el trinquete se
# abandonaría a la semana — quedaría un número inflado, con lugar libre para
# botones crudos nuevos que nadie ve entrar.
#
# No hay una tarea `diff`: el mensaje de falla de `test/lint/botones_test.rb`
# ya dice qué archivo se movió y para qué lado. Duplicarlo en una rake task
# obligaba a cargar el test —y Minitest se autoejecutaba— para leerle dos
# constantes.
namespace :botones do
  desc "Imprime el presupuesto del lint de botones, listo para pegar en test/lint/botones_test.rb"
  task presupuesto: :environment do
    imprimir_presupuesto("PRESUPUESTO", BotonesCrudos.censo)

    puts
    imprimir_presupuesto("BLANCO_SOBRE_TEAL",
                         BotonesCrudos.censo { |src| BotonesCrudos.contar_blanco_sobre_teal(src) })
  end

  def imprimir_presupuesto(nombre, censo)
    ancho = censo.keys.map(&:length).max.to_i

    # Sin coma en el último: rubocop la marca (`Style/TrailingCommaInHashLiteral`),
    # y un hash regenerado que ensucia el lint de estilo es fricción que nadie
    # va a querer pagar cada vez que migre una pantalla.
    filas = censo.sort_by { |ruta, n| [ -n, ruta ] }.map do |ruta, n|
      %(    #{%("#{ruta}").ljust(ancho + 3)} => #{n})
    end

    puts "  #{nombre} = {"
    puts filas.join(",\n")
    puts "  }.freeze"
    puts "  # total: #{censo.values.sum} en #{censo.size} archivos"
  end
end
