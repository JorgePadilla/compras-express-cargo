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

  # QA de PR-P.11a · La caja sin sucursal de retiro no traba F9; dos sucursales
  # cargadas y distintas sí, aunque la primera caja sea la que no tiene.
  test "F9: la tanda sin sucursal de retiro va con cualquiera, dos sucursales distintas no" do
    sin, sps, tgu = 3.times.map { caja }
    sin.update_columns(sucursal_id: nil)
    sps.update_columns(sucursal_id: sucursales(:zeron_sps).id)
    tgu.update_columns(sucursal_id: sucursales(:humuya_tgu).id)
    a, = medir([ sin ], { peso: "2" })
    b, = medir([ sps ], { peso: "2" })
    c, = medir([ tgu ], { peso: "2" })

    error = assert_raises(GuardarPreFacturaAuditada::NoSePuede) do
      guardar([ a.sesion, b.sesion, c.sesion ], [ sin.id, sps.id, tgu.id ])
    end
    assert_match(/Cada sucursal se factura aparte/, error.message)
    assert_match(/corregí la sucursal de retiro/, error.message)

    pf = guardar([ a.sesion, b.sesion ], [ sin.id, sps.id ])
    assert_equal [ sin.id, sps.id ].sort, pf.paquetes.map(&:id).sort
  end

  test "sin ninguna tanda" do
    assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([], []) }
  end

  # ── PR-P.11a · Lo que antes solo entraba por la puerta a mano ──────────

  test "una tanda prepagada en Miami se guarda con el simbólico, y el total es US$1 + ISV por caja" do
    cajas = 2.times.map { caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo") }
    bulto, = medir(cajas, { peso: "6" })

    pf = guardar([ bulto.sesion ], cajas.map(&:id))

    simbolo = CurrencyAware.convertir(PreFactura::PREPAGADO_MIAMI_SIMBOLICO, de: "USD", a: "LPS")
    assert_equal simbolo * 2, pf.subtotal
    assert_equal (simbolo * 2 * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP), pf.impuesto
    assert_equal 0, pf.pre_factura_items.find { |i| i.origen == "volumen" }.subtotal
  end

  test "«Sin manifiesto oficial»: la caja sin manifiesto entra, y la pre-factura queda sin manifiesto" do
    cajas = [ caja(manifiesto: nil) ]
    bulto, = medir(cajas, { peso: "2" })

    error = assert_raises(GuardarPreFacturaAuditada::NoSePuede) { guardar([ bulto.sesion ], cajas.map(&:id)) }
    assert_match(/Sin manifiesto oficial/, error.message)

    pf = guardar([ bulto.sesion ], cajas.map(&:id), hoja: @hoja.con("sin_manifiesto" => "1"))
    assert pf.persisted?
    assert_nil pf.manifiesto_id
    assert_includes HojaDePreparacion.pre_facturas_editables, pf, "se corrige desde «editar» como las demás"
  end

  # ── PR-P.11a · Volver a auditar después de anular (ya funcionaba) ──────
  #
  # Pregunta 7 de P.11 abierta: si al cliente ya se le avisó, el F9 nuevo
  # **vuelve a avisar** (`notificado_at` es de la pre-factura, y ésta es otra).

  def auditar_de_nuevo(bulto, cajas, hoja: @hoja)
    pf = guardar([ bulto.sesion ], cajas.map(&:id), hoja: hoja)
    assert pf.persisted?
    assert_equal cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    assert_equal [ bulto ], pf.pre_factura_items.select { |i| i.origen == "volumen" }.map(&:bulto),
                 "el mismo volumen: anular deja libre la tanda, no hay que medir de nuevo"
    pf
  end

  test "anulada después de avisar, la tanda se vuelve a auditar" do
    cajas = [ caja, caja ]
    bulto, = medir(cajas, { peso: "4" })
    ya = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                               disponible_en: 1.hour.ago)
    vieja = guardar([ bulto.sesion ], cajas.map(&:id), hoja: ya)
    assert vieja.notificado_at.present?
    assert vieja.anular!

    nueva = auditar_de_nuevo(bulto, cajas, hoja: ya)
    assert_not_equal vieja, nueva
    assert nueva.notificado_at.present?, "pregunta 7: se le vuelve a avisar"
    assert_equal vieja.reload.subtotal, nueva.subtotal, "cobra lo mismo"
  end

  test "anulada mientras consolidaba, la tanda se vuelve a auditar" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "4" })
    vieja = GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: [ bulto.sesion ], escaneadas: cajas.map(&:id),
                                          user: @user, modo: :consolidar).call
    assert_equal "consolidando_honduras", cajas.first.reload.estado
    assert vieja.anular!
    assert_equal "en_aduana", cajas.first.reload.estado

    nueva = auditar_de_nuevo(bulto, cajas)
    assert_equal @manana, nueva.notificar_at
  end

  test "anular la factura y después la pre-factura deja volver a auditar" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "4" })
    vieja = guardar([ bulto.sesion ], cajas.map(&:id))
    venta = vieja.facturar!
    assert venta.anular!
    assert_equal "pendiente", vieja.reload.estado
    assert vieja.anular!

    auditar_de_nuevo(bulto, cajas)
  end
end
