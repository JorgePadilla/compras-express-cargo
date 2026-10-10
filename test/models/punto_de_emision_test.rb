require "test_helper"

# PR-F1.1 · Un punto de emisión por sucursal de Honduras (Jorge, 2026-10-10).
class PuntoDeEmisionTest < ActiveSupport::TestCase
  test "las tablas fiscales salen de las inflections, no de la regla latina" do
    assert_equal "puntos_de_emision", PuntoDeEmision.name.tableize
    assert_equal "autorizaciones_sar", AutorizacionSar.name.tableize
    assert_equal "correlativos_fiscales", CorrelativoFiscal.name.tableize
    assert_equal "asientos_fiscales", AsientoFiscal.name.tableize
    assert_equal "PuntoDeEmision", "puntos_de_emision".classify
  end

  test "el identificador es EEE-PPP-TT" do
    sps = puntos_de_emision(:sps)
    assert_equal "000-001-01", sps.identificador("01")
    assert_equal "002-001-07", puntos_de_emision(:sam).identificador("07")
    assert_raises(ArgumentError) { sps.identificador("02") }
  end

  test "la sucursal llega a su punto" do
    assert_equal puntos_de_emision(:tgu), sucursales(:humuya_tgu).punto_de_emision
    assert_nil sucursales(:miami).punto_de_emision
  end

  test "un punto por sucursal: el modelo lo dice" do
    otro = PuntoDeEmision.new(sucursal: sucursales(:zeron_sps), establecimiento: "009", punto: "001")
    assert_not otro.valid?
    assert_includes otro.errors[:sucursal_id], "ya tiene un punto de emisión"
  end

  test "un punto por sucursal: la base lo dice aunque se saltee el modelo" do
    otro = PuntoDeEmision.new(sucursal: sucursales(:zeron_sps), establecimiento: "009", punto: "001")
    assert_raises(ActiveRecord::RecordNotUnique) { otro.save!(validate: false) }
  end

  test "la pareja establecimiento-punto no se repite" do
    sucursal = Sucursal.create!(codigo: "CEI", nombre: "La Ceiba", ubicacion: "honduras")
    repetido = PuntoDeEmision.new(sucursal: sucursal, establecimiento: "000", punto: "001")
    assert_not repetido.valid?
    assert repetido.errors[:punto].any?
    assert_raises(ActiveRecord::RecordNotUnique) { repetido.save!(validate: false) }
  end

  test "Miami no factura: solo una sucursal de Honduras tiene punto" do
    punto = PuntoDeEmision.new(sucursal: sucursales(:miami), establecimiento: "009", punto: "001")
    assert_not punto.valid?
    assert punto.errors[:sucursal].any?
  end

  test "establecimiento y punto son tres dígitos, en el modelo y en la base" do
    sucursal = Sucursal.create!(codigo: "CEI", nombre: "La Ceiba", ubicacion: "honduras")
    [ "1", "12", "1234", "A01", "" ].each do |malo|
      punto = PuntoDeEmision.new(sucursal: sucursal, establecimiento: malo, punto: "001")
      assert_not punto.valid?, "#{malo.inspect} no debería pasar"
    end

    error = assert_raises(ActiveRecord::StatementInvalid) do
      PuntoDeEmision.new(sucursal: sucursal, establecimiento: "0A1", punto: "001").save!(validate: false)
    end
    assert_kind_of PG::CheckViolation, error.cause
    assert PuntoDeEmision.create!(sucursal: sucursal, establecimiento: "003", punto: "001")
  end

  test "una sucursal con punto de emisión no se borra" do
    sucursal = sucursales(:san_manuel)
    assert_not sucursal.destroy
    assert sucursal.errors[:base].any?
    assert Sucursal.exists?(sucursal.id)
  end

  test "una sucursal sin punto ni paquetes sí se borra, con sus bodegas" do
    sucursal = Sucursal.create!(codigo: "CEI", nombre: "La Ceiba", ubicacion: "honduras")
    sucursal.sub_localidades.create!(codigo: "CEI01", nombre: "Bodega")
    assert sucursal.destroy
    assert_not SubLocalidad.exists?(sucursal_id: sucursal.id)
  end
end
