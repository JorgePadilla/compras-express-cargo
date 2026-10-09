require "test_helper"

# 2026-09-06 · La cola de trabajos, conectada de verdad.
#
# Del 2026-09-01 al 06 este repo tuvo `solid_queue` en el Gemfile, dos workers
# en `render.yaml` y **cero tablas**: el adaptador efectivo era `:async` y todo
# `deliver_later` moría en cada deploy. Estas afirmaciones son para que eso no
# vuelva a pasar en silencio — cada una es una forma en que puede volver.
class LaColaDeVerdadTest < ActiveSupport::TestCase
  test "las tablas de solid_queue existen en la base principal" do
    # Están en `structure.sql` porque entraron por una migración normal: Render
    # corre `db:migrate`, que jamás carga un `queue_schema.rb`.
    assert SolidQueue::Job.table_exists?
    assert SolidQueue::RecurringTask.table_exists?
    assert SolidQueue::ScheduledExecution.table_exists?, "sin ésta no hay `set(wait:)`"
  end

  test "producción usa solid_queue, sin base aparte" do
    prod = Rails.root.join("config/environments/production.rb").read

    assert_match(/^\s*config\.active_job\.queue_adapter = :solid_queue/, prod)
    # La **línea de config**, no la palabra: un comentario que la nombre no
    # cuenta (la trampa del lint de sonidos de esta mañana).
    assert_no_match(/^\s*config\.solid_queue\.connects_to/, prod,
                    "una base `queue` aparte no se crea con db:migrate: las tablas van en la principal")
    assert_not Rails.root.join("db/queue_schema.rb").exist?, "el esquema aparte se convirtió en migración"
    assert_no_match(/^\s*queue:/, Rails.root.join("config/database.yml").read)
  end

  test "los jobs nocturnos de recurring.yml existen y se pueden instanciar" do
    # Dormidos desde que se escribieron. Con la cola conectada, corren: el que
    # borra pre-alertas vacías a las 3am, cotizaciones expiradas, cuotas vencidas.
    tareas = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)["production"]

    assert_equal 3, tareas.size
    tareas.each_value { |t| assert Object.const_defined?(t["class"]), "#{t["class"]} no existe" }
  end

  test "el worker es un servidor aparte del web" do
    # Jorge: *"en un servidor solo para colas"*. El `background_worker` de
    # render.yaml es eso; el web no lleva `SOLID_QUEUE_IN_PUMA`.
    render = YAML.load_file(Rails.root.join("render.yaml"))
    workers = render["services"].select { |s| s["type"] == "background_worker" }
    webs = render["services"].select { |s| s["type"] == "web" }

    assert_equal 2, workers.size, "un worker por ambiente"
    webs.each do |w|
      assert_nil w["envVars"].find { |e| e["key"] == "SOLID_QUEUE_IN_PUMA" }, "#{w["name"]}: el web no corre la cola"
    end
  end
end
