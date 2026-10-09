# PR-C29.20 · El cazador de N+1, a pedido. Jorge, 2026-10-09: *"let's make
# sure we don't have n+1 in the code, if we have let's improve it"*.
#
#   CAZAR_N_MAS_1=1 bin/rails test            # y/o test:system
#   → tmp/n_mas_1.log   una línea por N+1 encontrado en un request
#   → tmp/n_mas_1.txt   el resumen, del que más se repite al que menos
#
# Sin la variable no se carga y no cambia nada.
#
# Por qué no `strict_loading`: en Rails 8.0 el modo `:n_plus_one_only` solo
# avisa en cadenas anidadas de `has_many` (el registro que trajo una colección
# marca a sus hijos), no en el caso de todos los días —una lista y una
# asociación por renglón—, y no ve un `count`, un `exists?` o un `find_by`
# adentro de un loop. Esto mira lo que de verdad pasa: dentro de un request,
# el mismo SELECT (con sus `$1` en lugar de los valores) disparado desde la
# misma línea de `app/` tres veces o más es un N+1.
module CazarNMas1
  UMBRAL = 3
  LOG = Rails.root.join("tmp/n_mas_1.log")
  RESUMEN = Rails.root.join("tmp/n_mas_1.txt")
  APP = Rails.root.join("app").to_s + "/"
  IGNORAR = %w[SCHEMA TRANSACTION].freeze

  module_function

  def huella(sql)
    sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\b\d+\b/, "?").gsub(/IN \([^)]*\)/i, "IN (?)").squish
  end

  def donde
    caller_locations.find { |l| l.path.start_with?(APP) }&.then { |l| "#{l.path.delete_prefix(Rails.root.to_s + '/')}:#{l.lineno}" }
  end

  def arrancar(ruta) = Thread.current[:cazar_n_mas_1] = { ruta: ruta, vistas: Hash.new(0) }

  def anotar(payload)
    actual = Thread.current[:cazar_n_mas_1]
    return unless actual
    return if payload[:cached] || IGNORAR.include?(payload[:name])
    return unless payload[:sql].to_s.lstrip.start_with?("SELECT")

    lugar = donde or return
    actual[:vistas][[ lugar, huella(payload[:sql]) ]] += 1
  end

  def cerrar
    actual = Thread.current[:cazar_n_mas_1] or return
    Thread.current[:cazar_n_mas_1] = nil
    repetidas = actual[:vistas].select { |_, n| n >= UMBRAL }
    return if repetidas.empty?

    File.open(LOG, "a") do |f|
      repetidas.each { |(lugar, sql), n| f.puts [ n, lugar, actual[:ruta], sql.truncate(220) ].join("\t") }
    end
  end

  def resumir
    return unless File.exist?(LOG)

    filas = File.readlines(LOG).map { |l| l.chomp.split("\t", 4) }
    por_lugar = filas.group_by { |_, lugar, _, sql| [ lugar, sql ] }.map do |(lugar, sql), grupo|
      [ grupo.map { |n, *| n.to_i }.max, grupo.size, lugar, grupo.map { |_, _, ruta, _| ruta }.uniq.first(3).join(" · "), sql ]
    end
    File.write(RESUMEN, por_lugar.sort_by { |max, veces, *| [ -max, -veces ] }.map { |f| f.join("\t") }.join("\n") + "\n")
  end
end

File.delete(CazarNMas1::LOG) if File.exist?(CazarNMas1::LOG) && ENV["CAZAR_N_MAS_1_SEGUIR"].nil?

ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |*, payload|
  CazarNMas1.arrancar("#{payload[:method]} #{payload[:path].to_s.split('?').first} (#{payload[:controller]}##{payload[:action]})")
end
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| CazarNMas1.anotar(payload) }
ActiveSupport::Notifications.subscribe("process_action.action_controller") { CazarNMas1.cerrar }
Minitest.after_run { CazarNMas1.resumir }
