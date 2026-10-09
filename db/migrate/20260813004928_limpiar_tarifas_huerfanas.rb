class LimpiarTarifasHuerfanas < ActiveRecord::Migration[8.0]
  # A7-25. Borra las tarifas de categoría que quedaron del backfill de PR-10.a y
  # que hoy **están cobrando**.
  #
  # Va como migración y no solo como rake porque el problema no es saber cuáles
  # son —eso ya lo dice `rake tarifas:huerfanas`— sino que alguien se acuerde de
  # correrlo en cada ambiente. Acá corre sola con el deploy.
  #
  # Encaja mejor de lo que parece: `config.schema_format = :sql`, así que una
  # base nueva se crea desde `structure.sql` y **no corre migraciones**. Esas
  # bases tampoco tienen el backfill, o sea que no tienen huérfanas. Las únicas
  # que ejecutan esto son las que vienen migradas de verdad — staging y
  # producción — que son justamente donde el problema existe.
  #
  # ⚠️ Es destructiva y **cambia precios**. A los clientes de una categoría
  # huérfana les empieza a aplicar el precio de lista, que en varios casos es
  # MÁS CARO que la fila que se borra. Por eso imprime la tabla completa de
  # impacto antes de borrar: el log del deploy queda como el registro de qué
  # cambió y para quién.
  def up
    unless defined?(TarifasHuerfanas)
      say "TarifasHuerfanas no está disponible; no hay nada que limpiar."
      return
    end

    hallazgos = TarifasHuerfanas.detectar

    if hallazgos.empty?
      say "No hay tarifas huérfanas: las de categoría son todas de la hoja de precios."
      return
    end

    # Sin esto el audit log guarda el cambio sin autor: la migración no corre
    # con un usuario logueado. Es plata — tiene que quedar de dónde salió.
    PaperTrail.request.whodunnit = "migracion 20260813004928 (A7-25)"

    say "#{hallazgos.size} tarifas de categoría que la hoja de precios no declara."
    say "Estaban en el nivel 'categoría', que gana sobre el precio de lista:"

    hallazgos.sort_by { |h| [ h.categoria, h.servicio ] }.each do |h|
      lista = h.precio_si_se_borra ? format("%.2f", h.precio_si_se_borra) : "sin precio de lista"
      direccion =
        if h.precio_si_se_borra.nil?          then "queda sin tarifa"
        elsif h.precio_si_se_borra > h.precio_actual then "SUBE"
        elsif h.precio_si_se_borra < h.precio_actual then "baja"
        else "igual"
        end

      say "#{h.categoria} / #{h.servicio.upcase}: " \
          "#{format('%.2f', h.precio_actual)} → #{lista} (#{direccion}) — #{h.motivo}", true
    end

    suben = hallazgos.count { |h| h.precio_si_se_borra && h.precio_si_se_borra > h.precio_actual }
    say "A #{suben} de #{hallazgos.size} les sube el precio.", true if suben.positive?

    # Una por una con `destroy`, no `delete_all`: cada fila deja su versión de
    # PaperTrail. Si mañana alguien pregunta por qué a un cliente le cambió el
    # precio, la respuesta tiene que estar en el historial.
    hallazgos.each { |h| h.tarifa.destroy! }

    say "#{hallazgos.size} tarifas borradas."
  ensure
    PaperTrail.request.whodunnit = nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "No se pueden restaurar precios borrados. Las filas quedaron en las " \
          "versiones de PaperTrail de `Tarifa` — de ahí se sacan a mano si hiciera falta."
  end
end
