require "test_helper"
require_relative "../support/con_app_host"
require Rails.root.join("lib/cai_ficticio_de_staging").to_s
require Rails.root.join("db/migrate/20261010150000_sembrar_cai_ficticio_de_staging").to_s

# PR-F1.5 · La migración de datos que le da a staging un CAI inventado por
# sucursal de Honduras. Se corre la migración de verdad (su `up`), con los
# frenos en el orden de FISCAL.md.
class CaiFicticioDeStagingTest < ActiveSupport::TestCase
  include ConAppHost

  setup do
    # Las fixtures ya traen puntos y un CAI: se parte de una base de staging
    # recién migrada, sin nada fiscal cargado.
    AutorizacionSar.delete_all
    CorrelativoFiscal.delete_all
    PuntoDeEmision.delete_all
  end

  # Un deploy de Render: `RAILS_ENV=production` en los dos servidores, y el
  # host dice cuál es (`Fiscal.produccion?`, que falla cerrado desde la QA de
  # PR-F1.1).
  def migrar(sample: "true", host: Fiscal::HOST_DE_STAGING)
    antes = ENV["SEED_SAMPLE_DATA"]
    sample.nil? ? ENV.delete("SEED_SAMPLE_DATA") : ENV["SEED_SAMPLE_DATA"] = sample
    en_servidor(host) do
      ActiveRecord::Migration.suppress_messages { SembrarCaiFicticioDeStaging.new.up }
    end
  ensure
    antes.nil? ? ENV.delete("SEED_SAMPLE_DATA") : ENV["SEED_SAMPLE_DATA"] = antes
  end

  test "sin SEED_SAMPLE_DATA no hace nada" do
    assert_no_difference -> { PuntoDeEmision.count + AutorizacionSar.count } do
      migrar(sample: nil)
    end
  end

  # QA de PR-F1.5 · Quien lo pone en false o en 0 lo quiere apagado.
  test "SEED_SAMPLE_DATA en false, 0 o vacío no siembra" do
    [ "false", "0", "", "no" ].each do |valor|
      assert_no_difference -> { PuntoDeEmision.count + AutorizacionSar.count }, "SEED_SAMPLE_DATA=#{valor.inspect}" do
        migrar(sample: valor)
      end
    end
  end

  test "en el host de producción no hace nada, aunque tenga SEED_SAMPLE_DATA" do
    assert_no_difference -> { PuntoDeEmision.count + AutorizacionSar.count } do
      migrar(host: Fiscal::HOST_DE_PRODUCCION)
    end
  end

  # QA de PR-F1.5 · Producción contesta hoy en cec-production.onrender.com, no
  # en el dominio de render.yaml, y Render ya no sincroniza el blueprint: su
  # APP_HOST real puede ser cualquiera. Con SEED_SAMPLE_DATA puesto por error,
  # la regla vieja (`APP_HOST == HOST_DE_PRODUCCION`) sembraba ahí.
  test "en un servidor que no es staging no hace nada, diga lo que diga APP_HOST" do
    [ "cec-production.onrender.com", nil, "", "CEC-STAGING.onrender.com", "cec-staging.onrender.com.evil.com" ].each do |host|
      assert_no_difference -> { PuntoDeEmision.count + AutorizacionSar.count }, "host #{host.inspect}" do
        migrar(host: host)
      end
    end
  end

  test "si ya hay una autorización cargada no agrega nada" do
    punto = PuntoDeEmision.create!(sucursal: sucursales(:zeron_sps), establecimiento: "000", punto: "001")
    AutorizacionSar.create!(punto_de_emision: punto, tipo_documento: "01", cai: "CAI-REAL", rango_inicio: 1,
                            rango_fin: 100, fecha_limite_emision: Date.current + 30)

    assert_no_difference -> { PuntoDeEmision.count + AutorizacionSar.count + CorrelativoFiscal.count } do
      migrar
    end
  end

  test "en staging crea un punto, un CAI ficticio y un correlativo por sucursal de Honduras" do
    migrar

    esperados = { "SPS" => "000-001-01", "TGU" => "001-001-01", "SAM" => "002-001-01" }
    assert_equal 3, PuntoDeEmision.count
    assert_equal 3, AutorizacionSar.count
    assert_equal 3, CorrelativoFiscal.where(tipo_documento: "01", ultimo: 0).count
    assert_nil sucursales(:miami).reload.punto_de_emision

    esperados.each do |codigo, identificador|
      a = AutorizacionSar.find_by!(cai: "FICTICIO-STAGING-#{codigo}-0001")
      assert_equal identificador, a.identificador
      assert a.ficticia?
      assert_equal [ 1, 5000 ], [ a.rango_inicio, a.rango_fin ]
      assert_equal Fiscal.hoy + 1.year, a.fecha_limite_emision
    end
  end

  test "es idempotente: correrla dos veces no duplica" do
    migrar
    assert_no_difference -> { AutorizacionSar.count } do
      migrar
    end
  end

  test "dirección y razón social de relleno solo donde están vacías" do
    sucursales(:zeron_sps).update!(direccion: nil)
    migrar

    assert_equal CaiFicticioDeStaging::DIRECCION_PENDIENTE, sucursales(:zeron_sps).reload.direccion
    assert_equal "Dirección de prueba, Tegucigalpa", sucursales(:humuya_tgu).reload.direccion
    assert_equal "Razón social de prueba", empresas(:singleton).reload.razon_social
  end

  test "la razón social vacía se rellena" do
    empresas(:singleton).update!(razon_social: nil)
    migrar
    assert_equal CaiFicticioDeStaging::RAZON_SOCIAL_PENDIENTE, empresas(:singleton).reload.razon_social
  end

  test "una sucursal de Honduras inactiva no recibe CAI" do
    sucursales(:san_manuel).update!(activo: false)
    migrar
    assert_equal %w[000-001-01 001-001-01], AutorizacionSar.all.map(&:identificador).sort
  end
end
