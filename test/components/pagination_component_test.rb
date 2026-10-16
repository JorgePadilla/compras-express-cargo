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
    assert_no_selector "nav[aria-label^='Paginación']"
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
  # ── PR-PAG.1 · Arriba y abajo ─────────────────────────────────────────────

  def muchos(prefijo, n = 30)
    cli = clientes(:juan)
    n.times { |i| Paquete.create!(tracking: "#{prefijo}-#{i}", cliente: cli, sucursal: sucursales(:miami)) }
    Paquete.where("tracking LIKE ?", "#{prefijo}-%")
  end

  test "arriba y abajo son dos nav con nombres distintos, y el margen lo pone el componente" do
    coll = muchos("PG-POS").page(1).per(10)
    with_request_url("/paquetes") do
      render_inline(PaginationComponent.new(collection: coll, label: "paquetes", posicion: :arriba))
      assert_selector "nav[aria-label='Paginación, arriba']"
      assert_selector "[data-paginacion='arriba'].mb-3"

      render_inline(PaginationComponent.new(collection: coll, label: "paquetes"))
      assert_selector "nav[aria-label='Paginación, abajo']"
      assert_selector "[data-paginacion='abajo'].mt-4"
    end
  end

  test "arriba no se dibuja cuando todo entra en una página: abajo sí" do
    coll = muchos("PG-UNA", 3).page(1).per(25)
    render_inline(PaginationComponent.new(collection: coll, label: "paquetes", posicion: :arriba))
    assert_no_text "Mostrando"

    render_inline(PaginationComponent.new(collection: coll, label: "paquetes"))
    assert_text(/Mostrando.*3/)
  end

  test "los links miden 44 px y anterior/siguiente tienen nombre también en el celular" do
    coll = muchos("PG-TAM").page(2).per(10)
    with_request_url("/paquetes") { render_inline(PaginationComponent.new(collection: coll, label: "paquetes")) }

    assert_selector "a[aria-label='Página 1'].min-h-11"
    assert_selector "span[aria-current='page']", text: "2"
    assert_selector "a[rel='prev'] .sr-only", text: "Anterior", visible: :all
    assert_selector "a[rel='next'] .sr-only", text: "Siguiente", visible: :all
  end

  test "el selector tiene rótulo, 44 px, y marca el per de la URL aunque no sea una opción" do
    coll = muchos("PG-PER").page(1).per(10)
    with_request_url("/paquetes?per=10") { render_inline(PaginationComponent.new(collection: coll, label: "paquetes")) }

    assert_selector "label[for='por_pagina_abajo']"
    assert_selector "select#por_pagina_abajo.min-h-11 option[selected]", text: "10"
  end

  test "una página fuera de rango ofrece volver a la primera" do
    coll = muchos("PG-OUT", 5).page(9).per(10)
    with_request_url("/paquetes?page=9") { render_inline(PaginationComponent.new(collection: coll, label: "paquetes")) }

    assert_text "Esta página ya no tiene paquetes"
    assert_link "Ir a la primera página"
  end
end
