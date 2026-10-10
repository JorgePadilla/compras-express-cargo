require "test_helper"

# PR-F1.6 · `db:seed` corre entero sobre una base vacía, y dos veces seguidas.
#
# Estuvo roto sin que nadie lo viera: desde PR-M2 el manifiesto exige al menos
# un tipo de envío **nuestro** (`tipo_envios`) y los cuatro demo solo ponían el
# texto `tipo_envio`; la pre-alerta pide `titulo` y las tres demo no lo traían.
# `db:seed` se caía a mitad de camino y una base de dev nueva quedaba sin
# manifiestos, pre-alertas, pre-facturas ni empresa. Nada lo corría: el deploy
# solo migra y la suite carga fixtures.
#
# Acá se vacía la base **adentro de la transacción del test** (`TRUNCATE` es
# transaccional en Postgres) y al final se deshace todo: las fixtures vuelven.
class SeedsTest < ActiveSupport::TestCase
  PROPIAS_DE_RAILS = %w[schema_migrations ar_internal_metadata].freeze

  setup do
    tablas = ActiveRecord::Base.connection.tables - PROPIAS_DE_RAILS
    ActiveRecord::Base.connection.execute("TRUNCATE #{tablas.map { |t| %("#{t}") }.join(', ')} RESTART IDENTITY CASCADE")
    @antes = ENV["SEED_SAMPLE_DATA"]
    ENV["SEED_SAMPLE_DATA"] = "true"
  end

  teardown do
    @antes.nil? ? ENV.delete("SEED_SAMPLE_DATA") : ENV["SEED_SAMPLE_DATA"] = @antes
  end

  def sembrar
    salida, = capture_io { load Rails.root.join("db/seeds.rb") }
    salida
  end

  test "siembra todo sobre una base vacía, y una segunda vez no se cae ni duplica" do
    assert_includes sembrar, "Seed completed!"

    %w[MA-000001 MA-000002 MA-FULL-001 MA-FULL-002].each do |numero|
      manifiesto = Manifiesto.find_by!(numero: numero)
      assert_equal %w[cer], manifiesto.tipo_envios.map(&:codigo), "#{numero} sin su tipo de envío"
    end
    assert PreAlerta.where(numero_documento: %w[PA-000001 PA-000002 PA-000003]).where.not(titulo: [ nil, "" ]).count == 3
    assert Empresa.exists?

    conteos = [ Manifiesto.count, PreAlerta.count, Paquete.count, Cliente.count ]
    assert_includes sembrar, "Seed completed!"
    assert_equal conteos, [ Manifiesto.count, PreAlerta.count, Paquete.count, Cliente.count ]
  end
end
