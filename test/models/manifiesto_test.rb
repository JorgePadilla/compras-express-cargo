require "test_helper"

class ManifiestoTest < ActiveSupport::TestCase
  test "valid manifiesto with required fields" do
    manifiesto = Manifiesto.new(numero: "MA-999999")
    assert manifiesto.valid?
  end

  test "requires unique numero" do
    manifiesto = Manifiesto.new(numero: "MA-000001")
    assert_not manifiesto.valid?
    assert_includes manifiesto.errors[:numero], "ya esta en uso"
  end

  test "auto-generates numero on create" do
    manifiesto = Manifiesto.create!
    assert_match /\AMA-\d{6}\z/, manifiesto.numero
  end

  test "auto-generated numero increments" do
    manifiesto = Manifiesto.create!
    assert_equal "MA-000003", manifiesto.numero
  end

  test "default estado is creado" do
    manifiesto = Manifiesto.new
    assert_equal "creado", manifiesto.estado
  end

  test "scope activos returns active manifests" do
    activos = Manifiesto.activos
    assert activos.all?(&:activo?)
  end

  test "scope buscar searches by numero" do
    results = Manifiesto.buscar("MA-000001")
    assert_includes results, manifiestos(:creado)
  end

  test "enviar! transitions manifest and paquetes to enviado" do
    manifiesto = manifiestos(:creado)
    paquete = paquetes(:empacado)
    paquete.update!(manifiesto: manifiesto)
    manifiesto.recalculate_totals!

    manifiesto.enviar!

    manifiesto.reload
    paquete.reload
    assert_equal "enviado", manifiesto.estado
    assert_not_nil manifiesto.fecha_enviado
    assert_equal "enviado_honduras", paquete.estado
  end

  test "recalculate_totals! updates counts" do
    manifiesto = manifiestos(:creado)
    paquete = paquetes(:recibido)
    paquete.update!(manifiesto: manifiesto)

    manifiesto.recalculate_totals!
    manifiesto.reload

    assert_equal 1, manifiesto.cantidad_paquetes
  end

  test "save retries on numero collision" do
    m1 = Manifiesto.create!
    expected_next = m1.numero.sub("MA-", "").to_i + 1

    # Manually take the next slot
    m2 = Manifiesto.create!(numero: "MA-#{expected_next.to_s.rjust(6, '0')}")

    # Should still succeed via retry
    m3 = Manifiesto.create!
    assert_match /\AMA-\d{6}\z/, m3.numero
    assert_not_equal m2.numero, m3.numero
  end
end
