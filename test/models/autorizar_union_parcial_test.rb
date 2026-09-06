require "test_helper"

# C26-03 · Facturar lo que hay: la excepción del grupo consolidado, con PIN.
class AutorizarUnionParcialTest < ActiveSupport::TestCase
  setup do
    @jefe = users(:supervisor_prefactura)
    @jefe.update!(pin: "1234", iniciales: "SP")
    @operario = users(:medidor)
    @pa = pre_alerta_consolidada("1ZPARC000000001", "1ZPARC000000002")
    p1 = llego(paquete_del_renglon(@pa, "1ZPARC000000001"))
    p1.update!(medido_at: Time.current, medido_por: "SP")
  end



  # Una pre-alerta consolidada nueva de Juan. Cada renglón crea su paquete
  # esperado (`pre_alerta_estado`); «llegar» es que Miami lo reciba y Honduras
  # lo escanee — acá, moverlo a `en_aduana`. Las de fixtures ya traen renglones
  # y corren los conteos; y vaciar una la borra por callback.
  def pre_alerta_consolidada(*trackings)
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    trackings.each { |t| pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto #{t.last(3)}", fecha: Date.current) }
    pa
  end

  def paquete_del_renglon(pa, tracking)
    pa.pre_alerta_paquetes.find_by(tracking: tracking).paquete
  end

  def llego(paquete)
    paquete.update_columns(estado: "en_aduana")
    paquete.reload
  end

  def autorizar(supervisor: @jefe, pin: "1234", motivo: "el cliente lo pidió")
    AutorizarUnionParcial.new(pre_alerta: @pa, supervisor: supervisor, pin: pin, motivo: motivo,
                              solicitado_por: @operario).call
  end

  test "sella la pre-alerta y deja registro en la bitácora" do
    assert_difference "Autorizacion.count", 1 do
      autorizar
    end

    @pa.reload
    assert_not_nil @pa.union_parcial_at
    assert_equal "SP", @pa.union_parcial_por
    a = Autorizacion.last
    assert_equal "union_parcial", a.accion
    assert_equal @pa, a.documento
    assert_match(/1ZPARC000000002/, a.detalle, "el detalle dice qué faltaba")
    assert_match(/Facturar parcial/, @pa.historial)
  end

  test "con PIN equivocado no pasa nada" do
    assert_raises(ActiveRecord::RecordInvalid) { autorizar(pin: "9999") }
    assert_nil @pa.reload.union_parcial_at
  end

  test "un rol sin PIN no autoriza, ni el operario de la estación" do
    cajero = users(:cajero)
    cajero.update!(pin: "1234")
    assert_raises(AutorizarUnionParcial::NoPermitido) { autorizar(supervisor: cajero) }
    assert_raises(AutorizarUnionParcial::NoPermitido) { autorizar(supervisor: @operario) }
  end

  test "sin motivo no pasa" do
    assert_raises(AutorizarUnionParcial::SinMotivo) { autorizar(motivo: "") }
  end

  test "con el grupo completo no hay nada que forzar" do
    @pa.pre_alerta_paquetes.where(tracking: "1ZPARC000000002").destroy_all

    assert_raises(AutorizarUnionParcial::YaCompleto) { autorizar }
  end
end
