require "test_helper"

class EntregaTest < ActiveSupport::TestCase
  test "valid entrega with required fields" do
    entrega = Entrega.new(
      cliente: clientes(:juan),
      tipo_entrega: "retiro_oficina",
      receptor_nombre: "Juan Perez",
      receptor_identidad: "0801199012345"
    )
    assert entrega.valid?
  end

  test "requires receptor_nombre" do
    entrega = Entrega.new(
      cliente: clientes(:juan),
      tipo_entrega: "retiro_oficina",
      receptor_identidad: "0801199012345"
    )
    assert_not entrega.valid?
    assert_includes entrega.errors[:receptor_nombre], "no puede estar en blanco"
  end

  test "requires receptor_identidad" do
    entrega = Entrega.new(
      cliente: clientes(:juan),
      tipo_entrega: "retiro_oficina",
      receptor_nombre: "Juan"
    )
    assert_not entrega.valid?
    assert_includes entrega.errors[:receptor_identidad], "no puede estar en blanco"
  end

  test "domicilio requires direccion_entrega and repartidor" do
    entrega = Entrega.new(
      cliente: clientes(:juan),
      tipo_entrega: "domicilio",
      receptor_nombre: "Juan",
      receptor_identidad: "0801199012345"
    )
    assert_not entrega.valid?
    assert_includes entrega.errors[:direccion_entrega], "no puede estar en blanco"
    assert entrega.errors[:repartidor].any?
  end

  test "auto-generates numero on create" do
    entrega = Entrega.create!(
      cliente: clientes(:juan),
      tipo_entrega: "retiro_oficina",
      receptor_nombre: "Juan",
      receptor_identidad: "123"
    )
    assert_match /\AEN-\d{6}\z/, entrega.numero
  end

  test "build_from_paquetes creates entrega with paquetes" do
    cliente = clientes(:juan)
    paquete = paquetes(:facturado_juan2) # not already in an entrega

    entrega = Entrega.build_from_paquetes(
      cliente, [paquete.id],
      tipo_entrega: "retiro_oficina",
      receptor_nombre: "Juan",
      receptor_identidad: "123"
    )
    assert entrega.save
    assert_equal 1, entrega.paquetes.count
  end

  test "despachar transitions pendiente to en_reparto" do
    entrega = entregas(:pendiente_juan)
    assert entrega.despachar!
    assert_equal "en_reparto", entrega.reload.estado
    assert_not_nil entrega.despachado_at
    entrega.paquetes.each do |p|
      assert_equal "en_reparto", p.reload.estado
    end
  end

  test "entregar transitions en_reparto to entregado" do
    entrega = entregas(:en_reparto_maria)
    assert entrega.entregar!
    assert_equal "entregado", entrega.reload.estado
    assert_not_nil entrega.entregado_at
    entrega.paquetes.each do |p|
      assert_equal "entregado", p.reload.estado
    end
  end

  test "anular returns paquetes to facturado" do
    entrega = entregas(:pendiente_juan)
    paquete_ids = entrega.paquetes.pluck(:id)

    assert entrega.anular!
    assert_equal "anulado", entrega.reload.estado
    paquete_ids.each do |pid|
      p = Paquete.find(pid)
      assert_equal "facturado", p.estado
      assert_nil p.entrega_id
    end
  end

  test "cannot anular entregado" do
    entrega = entregas(:en_reparto_maria)
    entrega.entregar!
    assert_not entrega.anular!
  end

  test "buscar scope finds by numero" do
    results = Entrega.buscar("EN-000001")
    assert_includes results, entregas(:pendiente_juan)
  end
end
