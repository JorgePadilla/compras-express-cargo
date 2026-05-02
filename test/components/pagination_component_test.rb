require "test_helper"

class PaginationComponentTest < ViewComponent::TestCase
  test "renderiza summary 'Mostrando X-Y de Z' con multi-page" do
    cli = clientes(:juan)
    25.times { |i| Paquete.create!(tracking: "PG-COMP-#{i}", cliente: cli, sucursal: sucursales(:miami)) }
    collection = Paquete.all.page(1).per(10)
    with_request_url("/paquetes") do
      render_inline(PaginationComponent.new(collection: collection, label: "paquetes"))
    end
    assert_text(/Mostrando.*1.*10.*de/m)
    assert_text "paquetes"
  end

  test "muestra 'Sin {label}' cuando empty" do
    collection = Paquete.where(tracking: "NOEXISTEX").page(1)
    render_inline(PaginationComponent.new(collection: collection, label: "paquetes"))
    assert_text "Sin paquetes"
  end

  test "single_page omite controles next/prev pero muestra summary" do
    cli = clientes(:juan)
    3.times { |i| Paquete.create!(tracking: "PG-SP-#{i}", cliente: cli, sucursal: sucursales(:miami)) }
    collection = Paquete.where("tracking LIKE 'PG-SP-%'").page(1).per(50)
    render_inline(PaginationComponent.new(collection: collection, label: "paquetes"))
    assert_text(/Mostrando.*3/)
    assert_no_selector "nav[aria-label='Paginación']"
  end

  test "first_index y last_index calculan rangos" do
    cli = clientes(:juan)
    25.times { |i| Paquete.create!(tracking: "PG-RNG-#{i}", cliente: cli, sucursal: sucursales(:miami)) }
    coll = Paquete.where("tracking LIKE 'PG-RNG-%'").page(2).per(10)
    component = PaginationComponent.new(collection: coll, label: "paquetes")
    assert_equal 11, component.first_index
    assert_equal 20, component.last_index
  end

  test "empty? cuando total_count == 0" do
    coll = Paquete.where(tracking: "ABSENT").page(1)
    component = PaginationComponent.new(collection: coll, label: "x")
    assert component.empty?
    assert_equal 0, component.first_index
  end
end
