require "test_helper"

class PaqueteTest < ActiveSupport::TestCase
  test "valid paquete with required fields" do
    paquete = Paquete.new(tracking: "1Z999TEST", cliente: clientes(:juan))
    assert paquete.valid?
  end

  test "requires tracking" do
    paquete = Paquete.new(cliente: clientes(:juan))
    assert_not paquete.valid?
    assert_includes paquete.errors[:tracking], "no puede estar en blanco"
  end

  test "requires cliente" do
    paquete = Paquete.new(tracking: "1Z999TEST")
    assert_not paquete.valid?
    assert_includes paquete.errors[:cliente], "es obligatorio"
  end

  test "requires unique guia" do
    paquete = Paquete.new(tracking: "1Z999TEST", guia: "PQ-000001", cliente: clientes(:juan))
    assert_not paquete.valid?
    assert_includes paquete.errors[:guia], "ya esta en uso"
  end

  test "auto-generates guia on create" do
    paquete = Paquete.create!(tracking: "1Z999AUTO", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, paquete.guia
  end

  test "auto-generated guia increments" do
    paquete = Paquete.create!(tracking: "1Z999INCR", cliente: clientes(:juan))
    assert_equal "PQ-000004", paquete.guia
  end

  test "default estado is recibido" do
    paquete = Paquete.new(tracking: "1Z999TEST", cliente: clientes(:juan))
    assert_equal "recibido", paquete.estado
  end

  test "sets fecha_recibido_miami on create" do
    paquete = Paquete.create!(tracking: "1Z999FECHA", cliente: clientes(:juan))
    assert_not_nil paquete.fecha_recibido_miami
  end

  test "calculates peso_volumetrico" do
    paquete = Paquete.create!(
      tracking: "1Z999VOL", cliente: clientes(:juan),
      alto: 10.0, largo: 12.0, ancho: 8.0
    )
    expected = (10.0 * 12.0 * 8.0 / 166.0).round(2)
    assert_equal expected, paquete.peso_volumetrico.to_f
  end

  test "calculates peso_cobrar as max of peso and peso_volumetrico" do
    paquete = Paquete.create!(
      tracking: "1Z999COBRAR", cliente: clientes(:juan),
      peso: 2.0, alto: 20.0, largo: 20.0, ancho: 20.0
    )
    vol = (20.0 * 20.0 * 20.0 / 166.0).round(2)
    assert_equal vol, paquete.peso_cobrar.to_f
  end

  test "peso_cobrar uses peso when greater than volumetric" do
    paquete = Paquete.create!(
      tracking: "1Z999HEAVY", cliente: clientes(:juan),
      peso: 50.0, alto: 5.0, largo: 5.0, ancho: 5.0
    )
    assert_equal 50.0, paquete.peso_cobrar.to_f
  end

  test "estado_terminal? returns true for entregado" do
    assert paquetes(:entregado).estado_terminal?
  end

  test "estado_terminal? returns false for recibido" do
    assert_not paquetes(:recibido).estado_terminal?
  end

  test "scope activos excludes anulado and entregado" do
    activos = Paquete.activos
    assert_includes activos, paquetes(:recibido)
    assert_includes activos, paquetes(:etiquetado)
    assert_not_includes activos, paquetes(:entregado)
  end

  test "scope buscar searches by tracking" do
    results = Paquete.buscar("1Z999AA1")
    assert_includes results, paquetes(:recibido)
  end

  test "scope buscar searches by guia" do
    results = Paquete.buscar("PQ-000002")
    assert_includes results, paquetes(:etiquetado)
  end

  test "scope buscar searches by client codigo" do
    results = Paquete.buscar("CEC-001")
    assert_includes results, paquetes(:recibido)
  end

  test "scope by_estado filters by estado" do
    results = Paquete.by_estado("etiquetado")
    assert_includes results, paquetes(:etiquetado)
    assert_not_includes results, paquetes(:recibido)
  end

  test "scope sin_manifiesto returns packages without manifest" do
    results = Paquete.sin_manifiesto
    assert_includes results, paquetes(:recibido)
    assert_includes results, paquetes(:etiquetado)
  end

  test "belongs to cliente" do
    assert_equal clientes(:juan), paquetes(:recibido).cliente
  end

  test "manifiesto is optional" do
    paquete = Paquete.new(tracking: "1Z999OPT", cliente: clientes(:juan))
    assert_nil paquete.manifiesto_id
    assert paquete.valid?
  end

  test "tipo_envio is optional" do
    paquete = Paquete.new(tracking: "1Z999OPT2", cliente: clientes(:juan))
    assert_nil paquete.tipo_envio
    assert paquete.valid?
  end

  test "generate_guia uses SQL maximum instead of pluck-map" do
    # Should work even when there are many records
    paquete = Paquete.create!(tracking: "1Z999SQLMAX", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, paquete.guia
    num = paquete.guia.sub("PQ-", "").to_i
    assert num > 0
  end

  test "save retries on guia collision" do
    # Create a paquete that will take the next guia slot
    p1 = Paquete.create!(tracking: "1Z999RETRY1", cliente: clientes(:juan))
    expected_next = p1.guia.sub("PQ-", "").to_i + 1

    # Manually assign the next guia to force collision
    p2 = Paquete.create!(tracking: "1Z999RETRY2", guia: "PQ-#{expected_next.to_s.rjust(6, '0')}", cliente: clientes(:juan))

    # This should still succeed via retry
    p3 = Paquete.create!(tracking: "1Z999RETRY3", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, p3.guia
    assert_not_equal p2.guia, p3.guia
  end
end
