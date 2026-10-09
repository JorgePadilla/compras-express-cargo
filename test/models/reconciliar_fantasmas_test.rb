require "test_helper"

# La limpieza de los fantasmas que ya estaban en la base antes de `PR-C7.20`.
#
# Vive en un método y no adentro del archivo de migración justamente para poder
# probar esto: que reconcilia, que **no** toca lo que no debe, y que llamarla dos
# veces no hace nada la segunda.
class ReconciliarFantasmasTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @tracking = "1Z999VIEJOFANTASMA"
  end

  test "reapunta la pre-alerta a la Caja 1 y borra el fantasma" do
    pap, fantasma, cajas = escena

    resultado = Paquete.reconciliar_fantasmas!

    assert_equal [ [ fantasma.id, cajas.first.id ] ], resultado[:reconciliados]
    assert_empty resultado[:saltados]
    assert_nil Paquete.find_by(id: fantasma.id), "el fantasma sigue ahí"
    assert_equal cajas.first.id, pap.reload.paquete_id
  end

  test "la pre-alerta queda al día" do
    pap, = escena
    assert_equal "pre_alerta", pap.pre_alerta.estado

    Paquete.reconciliar_fantasmas!

    assert_equal "recibido", pap.pre_alerta.reload.estado
  end

  test "las tareas del fantasma se mudan antes de borrarlo" do
    # `has_many :tareas, dependent: :destroy`: si no se mudan primero, se van con
    # él y el cliente pierde la instrucción que había dejado escrita.
    pap, fantasma, cajas = escena
    tarea = Tarea.create!(paquete: fantasma, pre_alerta_paquete: pap,
                          titulo: "Consolidar con lo de la otra semana",
                          estado: "pendiente", cliente: @cliente)

    Paquete.reconciliar_fantasmas!

    assert_equal cajas.first.id, tarea.reload.paquete_id
  end

  test "llamarla dos veces no hace nada la segunda" do
    escena
    Paquete.reconciliar_fantasmas!

    segunda = Paquete.reconciliar_fantasmas!

    assert_empty segunda[:reconciliados]
    assert_empty segunda[:saltados]
  end

  test "un fantasma que ya entró a una pre-factura no se borra: se reporta" do
    # Mismo espíritu que `CajaNoEliminable`. Un registro que ya está en un
    # documento no desaparece en silencio.
    _pap, fantasma, = escena
    PreFacturaItem.create!(pre_factura: pre_facturas(:borrador_juan), paquete: fantasma,
                           concepto: "Flete", subtotal: 10)

    resultado = Paquete.reconciliar_fantasmas!

    assert_empty resultado[:reconciliados]
    assert_equal [ [ fantasma.id, "pre_factura_items" ] ], resultado[:saltados]
    assert Paquete.exists?(fantasma.id)
  end

  test "no toca un esperado de otro cliente con el mismo tracking" do
    # El courier recicla números. Sin el filtro por cliente, esto borraría lo que
    # otra persona está esperando de verdad.
    escena
    otra = PreAlerta.create!(cliente: clientes(:maria), tipo_envio: tipo_envios(:cer),
                             titulo: "De otro cliente", estado: "pre_alerta")
    ajeno = otra.pre_alerta_paquetes.create!(tracking: @tracking, descripcion: "Lo suyo")

    Paquete.reconciliar_fantasmas!

    assert Paquete.exists?(ajeno.reload.paquete_id), "le borraron el esperado a otro cliente"
    assert_equal "pre_alerta_estado", ajeno.paquete.estado
  end

  test "dos esperados del mismo tracking no se comen entre ellos" do
    # Pasa cuando el cliente pre-alerta dos veces lo mismo, o cuando lo agrega a
    # una pre-alerta nueva sin borrar la vieja. Ninguno de los dos llegó: no hay
    # caja a la cual reapuntar, y tomar uno como "la caja" del otro borraría algo
    # que todavía viene en camino.
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciada dos veces", estado: "pre_alerta")
    uno = pa.pre_alerta_paquetes.create!(tracking: "1Z999DOSVECES", descripcion: "x")
    otra = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer),
                             titulo: "Y otra vez", estado: "pre_alerta")
    dos = otra.pre_alerta_paquetes.create!(tracking: "1Z999DOSVECES", descripcion: "x")

    resultado = Paquete.reconciliar_fantasmas!

    assert_empty resultado[:reconciliados]
    assert Paquete.exists?(uno.reload.paquete_id)
    assert Paquete.exists?(dos.reload.paquete_id)
  end

  test "un esperado sin cajas que hayan llegado se queda quieto" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer),
                           titulo: "Todavía viene", estado: "pre_alerta")
    solo = pa.pre_alerta_paquetes.create!(tracking: "1Z999TODAVIAVIENE", descripcion: "x")

    resultado = Paquete.reconciliar_fantasmas!

    assert_empty resultado[:reconciliados]
    assert Paquete.exists?(solo.reload.paquete_id)
  end

  private

  # Un fantasma como los que dejó /etiquetar: el esperado de una pre-alerta y,
  # al lado, las dos cajas que sí llegaron, con el mismo tracking.
  def escena
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer),
                           titulo: "La que dejó fantasma", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: @tracking, descripcion: "Lo que viene")
    fantasma = pap.reload.paquete

    cajas = Paquete.crear_split!(
      attrs: { cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: @tracking,
               descripcion: "Dos cajas", estado: "recibido_miami", user: users(:admin),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 2, por_caja: { 1 => { peso: 12.5 }, 2 => { peso: 30 } }
    )

    [ pap, fantasma, cajas ]
  end
end
