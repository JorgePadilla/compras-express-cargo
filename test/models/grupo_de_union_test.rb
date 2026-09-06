require "test_helper"

# C26-03 · «Unir»: el grupo de la pre-alerta consolidada, visto desde una caja.
#
# Jorge: *"al escanear le tiene que salir cuántos paquetes hacen falta para que
# se envíen todos con todas las medidas al mismo tiempo"*.
class GrupoDeUnionTest < ActiveSupport::TestCase
  setup do
    @t1, @t2, @t3 = %w[1ZUNIR000000001 1ZUNIR000000002 1ZUNIR000000003]
    @pa = pre_alerta_consolidada(@t1, @t2, @t3)
    @p1 = llego(paquete_del_renglon(@pa, @t1))
    @p2 = llego(paquete_del_renglon(@pa, @t2))
    # @t3 sigue esperado: no ha llegado.
  end

  test "cuenta llegados, medidos y faltantes con su dónde" do
    g = GrupoDeUnion.de(@p1)

    assert_equal @pa, g.pre_alerta
    assert_equal 3, g.total
    assert_equal 2, g.llegados
    assert_equal 0, g.medidos
    assert_equal [ [ @t1, "llegó, sin medir" ], [ @t2, "llegó, sin medir" ], [ @t3, "no ha llegado" ] ],
                 g.faltantes.map { |f| [ f.tracking, f.donde ] }
    assert_not g.completo?
    assert_not g.cerrada?
  end

  test "medir el último lo completa" do
    [ @p1, @p2 ].each { |p| p.update!(medido_at: Time.current, medido_por: "SP") }
    assert_not GrupoDeUnion.de(@p1).completo?, "todavía falta el tercero"

    p3 = llego(paquete_del_renglon(@pa, @t3))
    p3.update!(medido_at: Time.current, medido_por: "SP")

    g = GrupoDeUnion.de(@p1)
    assert_equal 3, g.medidos
    assert g.completo?
    assert_empty g.faltantes
  end

  test "un paquete que no llegó a Honduras no cuenta como llegado" do
    @p2.update_columns(estado: "recibido_miami")

    assert_equal 1, GrupoDeUnion.de(@p1).llegados
  end

  test "la excepción sellada se ve" do
    @pa.update_columns(union_parcial_at: Time.current, union_parcial_por: "SP")

    assert GrupoDeUnion.de(@p1).parcial_autorizado?
  end

  test "una pre-alerta consolidada ya cerrada se reconoce" do
    cerrada = pre_alertas(:finalizada)
    t = "1ZCERRADA0000001"
    cerrada.pre_alerta_paquetes.create!(tracking: t, descripcion: "Tarde", fecha: Date.current)
    p = llego(cerrada.pre_alerta_paquetes.find_by(tracking: t).paquete)

    g = GrupoDeUnion.de(p)
    assert_equal cerrada, g.pre_alerta
    assert g.cerrada?
  end

  test "sin pre-alerta consolidada no hay grupo" do
    p = Paquete.create!(tracking: "1ZSOLO0000000001", cliente: clientes(:maria), tipo_envio: tipo_envios(:cer),
                        sucursal_recepcion: sucursales(:miami), estado: "en_aduana", peso: 1)

    assert_nil GrupoDeUnion.de(p)
    assert_not p.listo_para_prefactura?, "sin medir no está listo"
    p.update!(medido_at: Time.current)
    assert p.listo_para_prefactura?, "medido y sin grupo: listo"
  end

  test "listo para pre-factura: medido y con el grupo completo, cerrado o forzado" do
    @p1.update!(medido_at: Time.current, medido_por: "SP")
    assert_not @p1.listo_para_prefactura?, "el grupo está incompleto"

    @pa.update_columns(union_parcial_at: Time.current, union_parcial_por: "SP")
    assert @p1.reload.listo_para_prefactura?, "con la excepción sellada, sí"
  end

  private

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
end
