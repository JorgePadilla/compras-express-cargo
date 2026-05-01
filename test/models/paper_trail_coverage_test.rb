require "test_helper"

# PR-D7: smoke test que confirma que cada modelo "audited" graba
# versiones cuando se crea / modifica. Yusef pidió "LOG en todas las
# paginas". Si alguien olvida `has_paper_trail` al agregar un modelo
# nuevo o lo remueve por error, este test lo cacha.
class PaperTrailCoverageTest < ActiveSupport::TestCase
  AUDITED_MODELS = %w[
    Paquete Cliente PreAlerta PreFactura Manifiesto Venta Entrega
    WarehouseReceipt Cotizacion NotaDebito NotaCredito Financiamiento
    Sucursal Proveedor MotivoRetencion PlantillaNotaCliente Carrier
    EmpresaManifiesto
  ].freeze

  test "cada modelo audited tiene paper_trail habilitado" do
    AUDITED_MODELS.each do |model_name|
      klass = model_name.constantize
      # paper_trail responde a `paper_trail` solo si has_paper_trail está
      # declarado; reflexionar el método como check confiable.
      assert klass.respond_to?(:paper_trail) && klass.method_defined?(:versions),
             "#{model_name} debe tener has_paper_trail (PR-D7)"
    end
  end

  test "MotivoRetencion graba versiones en create + update" do
    PaperTrail.request(whodunnit: users(:admin).id) do
      m = MotivoRetencion.create!(nombre: "PR-D7 test motivo")
      assert_equal 1, m.versions.count, "create graba 1 version"

      m.update!(activo: false)
      assert_equal 2, m.versions.count, "update graba 1 version más"
    end
  end

  test "Proveedor graba versiones en create + update" do
    PaperTrail.request(whodunnit: users(:admin).id) do
      p = Proveedor.create!(nombre: "PR-D7 test prov", tipo: "comercio")
      assert_equal 1, p.versions.count
      p.update!(activo: false)
      assert_equal 2, p.versions.count
    end
  end

  test "Sucursal graba versiones en update" do
    PaperTrail.request(whodunnit: users(:admin).id) do
      s = sucursales(:miami)
      versions_antes = s.versions.count
      s.update!(nombre: "Miami Test #{rand(99999)}")
      assert_equal versions_antes + 1, s.versions.count
    end
  end
end
