require "test_helper"

# C26-03 · «Unir»: el grupo de cajas que salen juntas, visto desde una.
#
# Jorge, corrigiendo la primera versión: *"si vienen 3 warehouse receipts y en
# la pre-alerta vienen 3, se tienen que unir… lo ideal es que estén los 3, y
# luego se midan y pesen los 3 y salgan las 3 stickers"*.
class GrupoDeUnionTest < ActiveSupport::TestCase
  setup do
    @t1, @t2, @t3 = %w[1ZUNIR000000001 1ZUNIR000000002 1ZUNIR000000003]
    @pa = pre_alerta_consolidada(@t1, @t2, @t3)
  end

  # ── Los cuatro estados salen de la base ──────────────────────────────────

  test "cada caja dice dónde está, sin inventar ninguna columna" do
    medida = llego(paquete_del_renglon(@pa, @t1))
    medida.update!(medido_at: Time.current, medido_por: "SP")
    llego(paquete_del_renglon(@pa, @t2))
    llego_a_miami(paquete_del_renglon(@pa, @t3))

    g = GrupoDeUnion.de(medida)

    assert_equal 3, g.total
    assert_equal [ "medida", "aqui", "en_camino" ], g.cajas.map(&:estado)
    assert_equal [ "medida", "acá, sin medir", "en Miami, todavía no llega acá" ], g.cajas.map(&:donde)
    assert_equal 1, g.medidas
    assert_equal 2, g.llegadas
    assert_not g.completo?
  end

  test "un tracking que el cliente declaró y Miami no tiene es una caja esperada, sin warehouse receipt" do
    aqui = llego(paquete_del_renglon(@pa, @t1))

    g = GrupoDeUnion.de(aqui)
    esperada = g.cajas.find { |c| c.tracking == @t3 }

    assert_equal "esperada", esperada.estado
    assert_nil esperada.paquete.numero_recepcion, "sin recibir en Miami no hay warehouse receipt"
  end

  # ── Cajas, no renglones: lo que Jorge corrigió ───────────────────────────

  test "un tracking que Miami partió en tres cajas son TRES cuadritos" do
    partido = llego(paquete_del_renglon(@pa, @t1))
    partido.update!(cantidad_paquetes: 3, numero_caja: 1)
    hermanas = (2..3).map { |n| caja_hermana(partido, n) }
    llego(paquete_del_renglon(@pa, @t2))
    llego(paquete_del_renglon(@pa, @t3))

    g = GrupoDeUnion.de(partido)

    assert_equal 5, g.total, "tres cajas del primer tracking más las otras dos"
    assert_equal [ 1, 2, 3 ], g.cajas.select { |c| c.tracking == @t1 }.map { |c| c.paquete.numero_caja }
    assert_includes g.cajas.map { |c| c.paquete&.id }, hermanas.last.id
  end

  test "un split sin pre-alerta también es un grupo: son varias stickers" do
    suelto = Paquete.create!(tracking: "1ZSPLIT000000009", cliente: clientes(:maria), tipo_envio: tipo_envios(:cer),
                             sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos",
                             peso: 2, cantidad_paquetes: 2, numero_caja: 1)
    hermana = caja_hermana(suelto, 2)

    g = GrupoDeUnion.de(suelto)

    assert_not_nil g
    assert_nil g.pre_alerta
    assert_not g.consolidada?, "no lo pidió el cliente: es una caja partida"
    assert_equal [ suelto.id, hermana.id ], g.cajas.map { |c| c.paquete.id }
  end

  test "una caja sola no arma grupo" do
    sola = Paquete.create!(tracking: "1ZSOLO0000000001", cliente: clientes(:maria), tipo_envio: tipo_envios(:cer),
                           sucursal_recepcion: sucursales(:miami), estado: "en_aduana", peso: 1)

    assert_nil GrupoDeUnion.de(sola)
  end

  # ── Completar el grupo ───────────────────────────────────────────────────

  test "el grupo se completa cuando están medidas TODAS las cajas" do
    cajas = [ @t1, @t2, @t3 ].map { |t| llego(paquete_del_renglon(@pa, t)) }
    cajas.first(2).each { |p| p.update!(medido_at: Time.current, medido_por: "SP") }

    assert_not GrupoDeUnion.de(cajas.first).completo?
    assert_equal 2, GrupoDeUnion.de(cajas.first).paquetes_medidos.size, "solo las medidas llevan sticker"

    cajas.last.update!(medido_at: Time.current, medido_por: "SP")

    g = GrupoDeUnion.de(cajas.first)
    assert g.completo?
    assert_empty g.faltantes
    assert_equal 3, g.paquetes_medidos.size
  end

  test "una pre-alerta consolidada ya cerrada se reconoce" do
    cerrada = pre_alertas(:finalizada)
    t = "1ZCERRADA0000001"
    cerrada.pre_alerta_paquetes.create!(tracking: t, descripcion: "Tarde", fecha: Date.current)

    g = GrupoDeUnion.de(llego(cerrada.pre_alerta_paquetes.find_by(tracking: t).paquete))

    assert_equal cerrada, g.pre_alerta
    assert g.cerrada?
  end

  # ── El gancho de la pre-factura ──────────────────────────────────────────

  test "listo para pre-factura: medido, y el grupo completo o pasado a mano" do
    caja = llego(paquete_del_renglon(@pa, @t1))
    caja.update!(medido_at: Time.current, medido_por: "SP")

    assert_not caja.listo_para_prefactura?, "el grupo está incompleto"

    @pa.update_columns(union_parcial_at: Time.current, union_parcial_por: "SP")

    assert caja.reload.listo_para_prefactura?
  end

  private

  # Una pre-alerta consolidada nueva de Juan. Cada renglón crea su paquete
  # «esperado» (`crear_paquete_esperado`), sin warehouse receipt: el número lo
  # genera Miami al recibirlo. Las de fixtures ya traen renglones y corren los
  # conteos; y vaciar una la borra por callback.
  def pre_alerta_consolidada(*trackings)
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    trackings.each { |t| pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto #{t.last(3)}", fecha: Date.current) }
    pa
  end

  def paquete_del_renglon(pa, tracking) = pa.pre_alerta_paquetes.find_by(tracking: tracking).paquete

  # Miami lo recibe: ahí nace el warehouse receipt.
  def llego_a_miami(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.reload
  end

  # Y llega a Honduras.
  def llego(paquete)
    llego_a_miami(paquete).update!(estado: "en_aduana")
    paquete.reload
  end

  def caja_hermana(madre, numero)
    Paquete.create!(tracking: madre.tracking, cliente: madre.cliente, tipo_envio: madre.tipo_envio,
                    sucursal_recepcion: sucursales(:miami), estado: madre.estado, descripcion: madre.descripcion,
                    peso: 2, numero_recepcion: madre.numero_recepcion,
                    cantidad_paquetes: madre.cantidad_paquetes, numero_caja: numero)
  end
end
