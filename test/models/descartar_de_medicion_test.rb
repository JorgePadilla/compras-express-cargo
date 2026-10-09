require "test_helper"

# C26-17 · Sacar una caja de la lista de pendientes — solo admin.
#
# Jorge: *"el admin debería poder quitarlos con algunas opciones de perdido, ya
# fue entregado, y una nota si es necesario, pero eso solo el admin"*.
class DescartarDeMedicionTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @admin.update!(iniciales: "AD")
    @paquete = Paquete.create!(tracking: "1ZDESC000000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "x", peso: 2)
  end

  def descartar(user: @admin, motivo: "perdido", nota: "se cayó del camión")
    DescartarDeMedicion.new(paquete: @paquete, user: user).descartar!(motivo: motivo, nota: nota)
  end

  test "sella el motivo, la nota, quién y cuándo" do
    descartar

    @paquete.reload
    assert_equal "perdido", @paquete.medicion_descartada_motivo
    assert_equal "se cayó del camión", @paquete.medicion_descartada_nota
    assert_equal "AD", @paquete.medicion_descartada_por
    assert_not_nil @paquete.medicion_descartada_at
    assert @paquete.descartado_de_medicion?
  end

  # Lo que **no** hace, que es el punto: un «entregado» sin entrega registrada
  # le mentiría al módulo de entregas y a la factura.
  test "no le cambia el estado al paquete" do
    descartar(motivo: "entregado")

    assert_equal "en_aduana", @paquete.reload.estado
  end

  test "sale de los pendientes, y vuelve al deshacerlo" do
    assert_includes Paquete.pendientes_de_medicion, @paquete

    descartar
    assert_not_includes Paquete.pendientes_de_medicion, @paquete

    DescartarDeMedicion.new(paquete: @paquete, user: @admin).restaurar!
    assert_includes Paquete.pendientes_de_medicion.reload, @paquete
    assert_nil @paquete.reload.medicion_descartada_motivo
  end

  test "un motivo inventado no pasa" do
    assert_raises(DescartarDeMedicion::SinMotivo) { descartar(motivo: "porque sí") }
    assert_raises(DescartarDeMedicion::SinMotivo) { descartar(motivo: "") }
    assert_not @paquete.reload.descartado_de_medicion?
  end

  # *"Pero eso solo el admin"*: ni el operario de la estación ni un jefe de
  # Honduras.
  test "solo admin: ni el medidor ni un supervisor" do
    [ users(:medidor), users(:supervisor_prefactura), users(:cajero), nil ].each do |user|
      assert_raises(DescartarDeMedicion::NoPermitido, "#{user&.rol || 'sin usuario'} no debería poder") do
        descartar(user: user)
      end
    end
    assert_not @paquete.reload.descartado_de_medicion?
  end

  test "deshacer también es solo de admin" do
    descartar

    assert_raises(DescartarDeMedicion::NoPermitido) do
      DescartarDeMedicion.new(paquete: @paquete, user: users(:medidor)).restaurar!
    end
  end
end
