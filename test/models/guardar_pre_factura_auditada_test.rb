require "test_helper"

# PR-P.5 · C30-18 · F9: guardar la pre-factura auditada.
#
# Yusef: *"¿cuándo pasan a disponibles? Cuando los agregás a la prefactura y le
# das F9"* — a la hora de la fecha de trabajo (`C30-16`, `RP-78`).
class GuardarPreFacturaAuditadaTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")
    @manana = 1.day.from_now.change(hour: 13, min: 0)
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                                  disponible_en: @manana)
  end

  def caja(**extra)
    Paquete.create!(tracking: "1ZGRD#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: @cer,
                    sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                    estado: "en_aduana", descripcion: "Zapatos", peso: 2, **extra)
  end

  def medir(cajas, *volumenes)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  def guardar(sesiones, escaneadas, hoja: @hoja)
    GuardarPreFacturaAuditada.new(hoja: hoja, sesiones: sesiones, escaneadas: escaneadas, user: @user).call
  end

  test "con todas las cajas escaneadas: la pre-factura por volumen, programada a la hora de la hoja" do
    cajas = 3.times.map { caja }
    uno, dos = medir(cajas, { peso: "2" }, { peso: "5" })

    pf = guardar([ uno.sesion ], cajas.map(&:id))

    assert pf.persisted?
    assert_equal @cliente, pf.cliente
    assert_equal [ uno, dos ], pf.pre_factura_items.select { |i| i.origen == "volumen" }.map(&:bulto)
    assert_equal cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    assert_equal @manifiesto.id, pf.manifiesto_id
    assert_equal @user, pf.auditado_por
    assert_equal @manana, pf.notificar_at
    assert_equal @manana.to_date, pf.fecha_trabajo
    assert_nil pf.consolidando_at
    assert_nil pf.notificado_at, "la hora es mañana: todavía no avisa"
    assert cajas.all? { |c| c.reload.estado == "en_aduana" }, "siguen en aduana hasta la hora"
  end

  test "si falta escanear una caja, no se guarda nada y se dice cuál" do
    cajas = 2.times.map { caja }
    bulto, = medir(cajas, { peso: "2" })

    error = assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([ bulto.sesion ], [ cajas.first.id ]) }
    assert_match(/Faltan 1 caja/, error.message)
    assert_nil cajas.last.reload.pre_factura_id
  end

  test "una caja con tarea que bloquea: se frena acá, no a las 7:30 sin nadie mirando" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "2" })
    Tarea.create!(paquete: cajas.first, titulo: "Revisar", cliente: @cliente, bloquea_avance: true,
                  estado: "pendiente", origen: "manual")

    error = assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([ bulto.sesion ], cajas.map(&:id)) }
    assert_match(/tarea pendiente/, error.message)
  end

  test "si entre el escaneo y el F9 otra pre-factura se llevó la caja, no se cobra dos veces" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "2" })
    cajas.first.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)

    assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([ bulto.sesion ], cajas.map(&:id)) }
  end

  test "si la hora ya pasó, la carga queda disponible y el aviso sale ya" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "2" })
    hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                                 disponible_en: 1.hour.ago)

    pf = guardar([ bulto.sesion ], cajas.map(&:id), hoja: hoja)

    assert pf.notificado_at.present?, "la hora ya pasó: avisa al apretar F9"
    assert_equal "disponible_entrega", cajas.first.reload.estado
  end

  test "sin ninguna tanda" do
    assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([], []) }
  end
end
