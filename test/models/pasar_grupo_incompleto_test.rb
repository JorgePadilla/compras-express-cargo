require "test_helper"

# C26-03 · «Facturar lo que hay»: seguir sin el grupo completo.
#
# Jorge: *"hay una posibilidad de que solo estén 2: en ese caso se pone una
# alerta y se pasa"*. Sin PIN — la primera versión lo pedía y él lo corrigió.
class PasarGrupoIncompletoTest < ActiveSupport::TestCase
  setup do
    @operario = users(:medidor)
    @operario.update!(iniciales: "MD")
    @pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                            tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                            titulo: "Consolidado", creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    @pa.pre_alerta_paquetes.create!(tracking: "1ZPARC000000001", descripcion: "Zapatos", fecha: Date.current)
    @pa.pre_alerta_paquetes.create!(tracking: "1ZPARC000000002", descripcion: "Gorra", fecha: Date.current)
    llegada = @pa.pre_alerta_paquetes.first.paquete
    llegada.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    llegada.update!(estado: "en_aduana", medido_at: Time.current, medido_por: "MD")
  end

  test "sella la pre-alerta y deja en su historial qué faltaba" do
    PasarGrupoIncompleto.new(pre_alerta: @pa, user: @operario).call

    @pa.reload
    assert_not_nil @pa.union_parcial_at
    assert_equal "MD", @pa.union_parcial_por
    assert_match(/sin el grupo completo \(MD\)/, @pa.historial)
    assert_match(/1 de 2 medidas/, @pa.historial)
    assert_match(/1ZPARC000000002 \(no ha llegado a Miami\)/, @pa.historial, "dice cuál faltaba y dónde estaba")
  end

  test "no pide PIN de nadie: el operario de la estación puede" do
    assert_nothing_raised { PasarGrupoIncompleto.new(pre_alerta: @pa, user: @operario).call }
    assert_nil @operario.pin_digest, "el rol de estación no tiene PIN, y no le hace falta"
  end

  test "con el grupo completo no hay nada que forzar" do
    faltante = @pa.pre_alerta_paquetes.last.paquete
    faltante.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    faltante.update!(estado: "en_aduana", medido_at: Time.current, medido_por: "MD")

    assert_raises(PasarGrupoIncompleto::YaCompleto) do
      PasarGrupoIncompleto.new(pre_alerta: @pa, user: @operario).call
    end
  end
end
