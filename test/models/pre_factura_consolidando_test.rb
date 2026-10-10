require "test_helper"

# PR-P.6 · C30-18 · F8: guardar consolidando, y la tanda nueva que se le agrega.
#
# F8 guarda e imprime con CONSOLIDANDO atravesado y **no avisa**: las cajas a
# `consolidando_honduras`, `consolidando_at` puesto, `notificar_at` vacío.
# Cuando llega lo que faltaba, escanear un volumen suyo la reabre, se le agrega
# la tanda nueva —Yusef: *"¿desea agregar más paquetes a este volumen, o nuevo
# volumen?"*—, y F9 la programa como cualquier otra.
class PreFacturaConsolidandoTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")
    Tarifa.create!(tipo_envio: tipo_envios(:cem), precio_libra: 3.00, moneda: "USD")
    @manana = 1.day.from_now.change(hour: 13, min: 0)
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id, tipo_envios(:cem).id ],
                                  manifiesto_ids: [ @manifiesto.id ], disponible_en: @manana)
  end

  def caja(tipo_envio: @cer)
    Paquete.create!(tracking: "1ZCON#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: tipo_envio,
                    sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                    estado: "en_aduana", descripcion: "Zapatos", peso: 2)
  end

  def medir(cajas, *volumenes) = MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)

  def guardar(sesiones, escaneadas, modo:, pre_factura_id: nil)
    GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: sesiones, escaneadas: escaneadas, user: @user,
                                  modo: modo, pre_factura_id: pre_factura_id).call
  end

  def consolidando
    @primeras = 2.times.map { caja }
    @bulto, = medir(@primeras, { peso: "4" })
    guardar([ @bulto.sesion ], @primeras.map(&:id), modo: :consolidar)
  end

  # ── F8 ────────────────────────────────────────────────────────────────

  test "F8 deja las cajas consolidando y no le avisa a nadie, ni a la hora" do
    pf = nil
    assert_no_enqueued_emails { pf = consolidando }

    assert pf.consolidando_at.present?
    assert_nil pf.notificar_at
    assert_nil pf.notificado_at
    assert @primeras.all? { |c| c.reload.estado == "consolidando_honduras" }

    assert_no_enqueued_emails { assert_equal 0, HacerDisponibles.call(ahora: 2.days.from_now) }
    assert @primeras.all? { |c| c.reload.estado == "consolidando_honduras" }, "el barrido ni la mira"
  end

  test "F8 no pregunta por tareas que bloquean: no avanza a nadie" do
    @primeras = [ caja ]
    @bulto, = medir(@primeras, { peso: "2" })
    Tarea.create!(paquete: @primeras.first, titulo: "Revisar", cliente: @cliente, bloquea_avance: true,
                  estado: "pendiente", origen: "manual")

    assert guardar([ @bulto.sesion ], @primeras.map(&:id), modo: :consolidar).persisted?
  end

  # ── Reabrir y agregar ─────────────────────────────────────────────────

  test "escanear un volumen de una consolidando la reabre" do
    pf = consolidando
    qr = "MED #{@primeras.first.tracking} 4.00"

    r = AuditoriaDeTanda.new(hoja: @hoja).volumen(qr)

    assert_equal :consolidando, r.tipo
    assert_equal pf, r.pre_factura
  end

  test "pero una pre-factura que ya no está consolidando sigue siendo «ya pre-facturada»" do
    pf = consolidando
    pf.update_columns(consolidando_at: nil)

    assert_equal :ya_prefacturada, AuditoriaDeTanda.new(hoja: @hoja).volumen("MED #{@primeras.first.tracking} 4.00").tipo
  end

  test "la tanda nueva se agrega, y F9 la programa: las líneas viejas no cambian" do
    pf = consolidando
    vieja = pf.pre_factura_items.find_by(origen: "volumen")
    monto_viejo = vieja.subtotal

    nuevas = [ caja ]
    nuevo, = medir(nuevas, { peso: "6" })
    pf = guardar([ @bulto.sesion, nuevo.sesion ], nuevas.map(&:id), modo: :avisar, pre_factura_id: pf.id)

    assert_equal [ @bulto, nuevo ].map(&:id).sort, pf.pre_factura_items.where(origen: "volumen").map(&:bulto_id).sort,
                 "una línea por volumen, sin repetir la vieja"
    assert_equal monto_viejo, vieja.reload.subtotal
    assert_equal (@primeras + nuevas).map(&:id).sort, pf.paquetes.map(&:id).sort
    assert_nil pf.consolidando_at
    assert_equal @manana, pf.notificar_at
    assert (@primeras + nuevas).all? { |c| c.reload.estado == "en_aduana" }, "vuelven a aduana hasta la hora"
  end

  test "agregar y volver a dejarla consolidando" do
    pf = consolidando
    nuevas = [ caja ]
    nuevo, = medir(nuevas, { peso: "6" })

    pf = guardar([ @bulto.sesion, nuevo.sesion ], nuevas.map(&:id), modo: :consolidar, pre_factura_id: pf.id)

    assert pf.consolidando_at.present?
    assert_nil pf.notificar_at
    assert_equal "consolidando_honduras", nuevas.first.reload.estado
  end

  test "la tanda nueva tiene que estar escaneada; las viejas ya lo estaban" do
    pf = consolidando
    nuevas = 2.times.map { caja }
    nuevo, = medir(nuevas, { peso: "6" })

    error = assert_raises(GuardarPreFacturaAuditada::NoSePuede) do
      guardar([ @bulto.sesion, nuevo.sesion ], [ nuevas.first.id ], modo: :avisar, pre_factura_id: pf.id)
    end
    assert_match(/Faltan 1 caja/, error.message)
  end

  test "una tanda de otro servicio no se le agrega" do
    pf = consolidando
    cem = [ caja(tipo_envio: tipo_envios(:cem)) ]
    otro, = medir(cem, { peso: "3" })

    r = AuditoriaDeTanda.new(hoja: @hoja, sesiones: [ @bulto.sesion ], abierta: pf).volumen("MED #{cem.first.tracking} 3.00")
    assert_equal :no_va_junto, r.tipo

    assert_raises(GuardarPreFacturaAuditada::NoSePuede) do
      guardar([ @bulto.sesion, otro.sesion ], cem.map(&:id), modo: :avisar, pre_factura_id: pf.id)
    end
  end

  # QA · El servidor no confía en que la pantalla le mande las tandas viejas:
  # con la nueva sola, igual se pregunta contra las de la reabierta.
  test "aunque el pedido traiga solo la tanda nueva, otro servicio no se le agrega" do
    pf = consolidando
    cem = [ caja(tipo_envio: tipo_envios(:cem)) ]
    otro, = medir(cem, { peso: "3" })

    assert_raises(GuardarPreFacturaAuditada::NoSePuede) do
      guardar([ otro.sesion ], cem.map(&:id), modo: :avisar, pre_factura_id: pf.id)
    end
    assert_equal [ @cer.id ], pf.reload.paquetes.map(&:tipo_envio_id).uniq
  end

  test "F9 con solo la tanda nueva en el pedido igual devuelve las viejas a aduana" do
    pf = consolidando
    nuevas = [ caja ]
    nuevo, = medir(nuevas, { peso: "6" })

    pf = guardar([ nuevo.sesion ], nuevas.map(&:id), modo: :avisar, pre_factura_id: pf.id)

    assert_nil pf.consolidando_at
    assert (@primeras + nuevas).all? { |c| c.reload.estado == "en_aduana" }
  end

  test "anular una consolidando devuelve las cajas a aduana" do
    pf = consolidando
    pf.anular!
    assert @primeras.all? { |c| c.reload.estado == "en_aduana" }
  end
end
