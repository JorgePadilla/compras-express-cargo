require "test_helper"

class ManifiestoTest < ActiveSupport::TestCase
  # C21-03 · Desde la Conversación 21 un manifiesto sin ningún tipo de envío
  # NUESTRO no es válido: *"no puede ser sin ninguno, tiene que llevar uno
  # mínimo"*. Es lo que decide qué paquetes salen al finalizar. Estos tests son
  # de la numeración, así que el tipo va por el helper y no estorba la lectura.
  def crear_manifiesto(**attrs)
    Manifiesto.create!(**attrs, tipo_envios: [ tipo_envios(:cer) ])
  end

  def nuevo_manifiesto(**attrs)
    Manifiesto.new(**attrs, tipo_envios: [ tipo_envios(:cer) ])
  end

  test "valid manifiesto with required fields" do
    manifiesto = nuevo_manifiesto(numero: "MA-999999")
    assert manifiesto.valid?
  end

  test "requires unique numero" do
    manifiesto = nuevo_manifiesto(numero: "MA-000001")
    assert_not manifiesto.valid?
    assert_includes manifiesto.errors[:numero], "ya esta en uso"
  end

  test "auto-generates numero on create" do
    manifiesto = crear_manifiesto
    assert_match /\AMA-\d{6}\z/, manifiesto.numero
  end

  test "auto-generated numero increments" do
    manifiesto = crear_manifiesto
    assert_equal "MA-000003", manifiesto.numero
  end

  test "default estado is creado" do
    manifiesto = nuevo_manifiesto
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
    m1 = crear_manifiesto
    expected_next = m1.numero.sub("MA-", "").to_i + 1

    # Manually take the next slot
    m2 = crear_manifiesto(numero: "MA-#{expected_next.to_s.rjust(6, '0')}")

    # Should still succeed via retry
    m3 = crear_manifiesto
    assert_match /\AMA-\d{6}\z/, m3.numero
    assert_not_equal m2.numero, m3.numero
  end
end
