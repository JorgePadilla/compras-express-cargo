ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Advance sequences past fixture data to avoid uniqueness conflicts
    parallelize_setup do
      %w[entregas_numero_seq aperturas_caja_numero_seq ingresos_caja_numero_seq egresos_caja_numero_seq].each do |seq|
        ActiveRecord::Base.connection.execute("SELECT setval('#{seq}', 100)")
      end
    end

    # PR-13.d: el cache de ActionController dejó de ser `:null_store` para que
    # `rate_limit` pueda contar — sin eso un límite de intentos pasaría los
    # tests sin existir, y el único que protege un PIN de 4 dígitos es ese.
    #
    # Pero el contador vive en el proceso, así que sin limpiarlo los intentos se
    # acumulan entre tests: el `rate_limit` del login es por IP y todos los
    # tests salen de 127.0.0.1, así que a partir del test 11 se caían solos.
    setup { ActionController::Base.cache_store.clear }

    # ── La apertura de caja «de hoy» tiene que seguir siendo de hoy ──────────
    #
    # `aperturas_caja.yml` congela `<%= Date.current %>` **cuando se cargan las
    # fixtures**, y la app pregunta `Date.current` **cuando corre el request**.
    # Entre las dos cosas hay una suite entera, y si el reloj cruza la
    # medianoche en el medio la fila «hoy» pasa a ser de ayer: cuatro tests de
    # caja fallan, y fallan **solo a esa hora**.
    #
    # No es hipotético. Pasó en CI el 2026-09-02 a las 06:00:14 UTC, que con
    # `config.time_zone = "Central America"` son las **00:00:14** de Honduras —
    # catorce segundos después de la medianoche—, en un PR que no tocaba caja.
    #
    # Se re-estampa solo la **abierta**: `ayer_cerrada` tiene que quedarse
    # donde está, que su gracia es justamente no ser de hoy. Y solo toca filas
    # de fixture, porque `setup` corre antes del cuerpo del test.
    setup { AperturaCaja.where(estado: "abierta").update_all(fecha: Date.current) }

    # Add more helper methods to be used by all tests here...
  end
end
