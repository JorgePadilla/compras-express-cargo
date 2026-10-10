require "test_helper"

# PR-P.10 · La pre-factura a mano es la puerta de las excepciones, y cobra por
# volumen cuando el paquete tiene uno.
#
# Lo que cuidan estos tests es la plata: lo que va por volumen cobra
# **exactamente** lo que cobraría F9 (`ArmarPreFacturaPorVolumen`), lo que va
# por paquete **exactamente** lo de siempre (`build_from_paquetes`), y los
# cargos automáticos salen una vez por caja aunque las dos cosas convivan en el
# mismo documento.
class ArmarPreFacturaManualTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    Tarifa.delete_all
  end

  def caja(cliente: @cliente, peso: 2, **extra)
    Paquete.create!(tracking: "1ZMAN#{SecureRandom.hex(5).upcase}", cliente: cliente,
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", peso: peso, **extra)
  end

  def medir(cajas, *volumenes)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  def armar(*paquetes) = ArmarPreFacturaManual.call(cliente: @cliente, paquete_ids: paquetes.map(&:id), user: @user)
  def por_volumen(sesion) = ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: [ sesion ], user: @user)

  def tarifa_cer(**extra)
    Tarifa.create!({ tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD" }.merge(extra))
  end

  def cambio_de_servicio
    ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.precio_venta = 15
      s.moneda = "USD"
      s.costo = 0
    end
  end

  # Lo que importa de una línea para la plata y para el documento.
  def huella(items)
    items.map { |i| [ i.paquete_id, i.bulto_id, i.origen, i.concepto, i.peso_cobrar, i.precio_libra, i.subtotal, i.minimo_aplicado ] }
         .sort_by(&:to_s)
  end

  def de_origen(pf, origen) = pf.pre_factura_items.select { |i| i.origen == origen }

  def totales(pf)
    pf.calcular_totales
    [ pf.subtotal, pf.impuesto, pf.total ]
  end

  # ── Sin tanda: lo de siempre ────────────────────────────────────────────

  test "un paquete sin medir sale igual que build_from_paquetes, línea por línea y en el total" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    liviano = caja(peso: 1)
    pesado = caja(peso: 37.2)

    r = armar(liviano, pesado)
    viejo = PreFactura.build_from_paquetes(@cliente, [ liviano.id, pesado.id ], user: @user)

    assert_equal huella(viejo.pre_factura_items), huella(r.pre_factura.pre_factura_items)
    assert_empty r.por_volumen
    assert_empty r.rechazos
    assert_equal [ @user, Date.current ], [ r.pre_factura.creado_por, r.pre_factura.fecha_trabajo ]

    r.pre_factura.save!
    viejo.save!
    assert_equal [ viejo.subtotal, viejo.impuesto, viejo.total ],
                 [ r.pre_factura.subtotal, r.pre_factura.impuesto, r.pre_factura.total ]
  end

  test "un id que no es facturable no entra, aunque lo manden" do
    tarifa_cer
    ajeno = caja(cliente: clientes(:maria))
    cobrado = caja(peso: 3)
    PreFactura.build_from_paquetes(@cliente, [ cobrado.id ], user: @user).save!

    assert_empty armar(ajeno, cobrado).pre_factura.pre_factura_items
  end

  # ── Con tanda: por volumen ──────────────────────────────────────────────

  test "un paquete de una tanda medida cobra el volumen, igual que F9" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = [ caja(peso: 2), caja(peso: 2) ]
    bulto, = medir(cajas, { peso: "12" }) # el volumen pesó 12; Miami dijo 2 + 2

    r = armar(*cajas)
    f9 = por_volumen(bulto.sesion)

    assert_equal [ bulto.sesion ], r.por_volumen
    assert_equal huella(f9.pre_factura_items), huella(r.pre_factura.pre_factura_items)
    assert_equal 1, de_origen(r.pre_factura, "volumen").size
    assert de_origen(r.pre_factura, "caja_del_volumen").all? { |i| i.subtotal.zero? }
    assert_empty de_origen(r.pre_factura, "manual"), "ninguna caja de la tanda se cobra por su peso de Miami"
    assert_equal totales(f9), totales(r.pre_factura)
    assert_equal (BigDecimal("12") * CurrencyAware.convertir(4.50, de: "USD", a: "LPS")).round(2), r.pre_factura.subtotal
  end

  test "elegir UNA caja de una tanda de dos trae las dos" do
    tarifa_cer
    cajas = [ caja, caja ]
    bulto, = medir(cajas, { peso: "8" })

    r = armar(cajas.first)

    assert_equal cajas.map(&:id).sort, de_origen(r.pre_factura, "caja_del_volumen").map(&:paquete_id).sort
    assert_equal totales(por_volumen(bulto.sesion)), totales(r.pre_factura)
    assert_equal cajas.map(&:id).sort, r.cajas_de_la_tanda(bulto.sesion).map(&:id).sort

    r.pre_factura.save!
    assert_equal [ r.pre_factura.id ] * 2, cajas.map { |c| c.reload.pre_factura_id }, "las dos quedan tomadas"
  end

  test "una tanda de dos volúmenes cobra los dos" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = 3.times.map { caja }
    uno, dos = medir(cajas, { peso: "2" }, { peso: "30" })

    r = armar(cajas.last)

    assert_equal [ uno, dos ], r.lineas_de_volumen(uno.sesion).map(&:bulto)
    assert_equal totales(por_volumen(uno.sesion)), totales(r.pre_factura)
  end

  # ── La tanda que el armador por volumen rechaza: por paquete, con motivo ─

  test "una tanda con una caja prepagada en Miami va por paquete, con el simbólico y el motivo" do
    tarifa_cer
    normal = caja(peso: 5)
    prepagada = caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo")
    bulto, = medir([ normal, prepagada ], { peso: "8" })

    r = armar(normal, prepagada)

    assert_empty r.por_volumen
    assert_match(/prepagada en Miami/, r.rechazos[bulto.sesion])
    assert_equal r.rechazos[bulto.sesion], r.rechazo_de(normal.reload)
    assert_empty de_origen(r.pre_factura, "volumen")
    assert_equal [ prepagada ], r.pre_factura.prepagados_miami_detected
    assert_equal huella(PreFactura.build_from_paquetes(@cliente, [ normal.id, prepagada.id ], user: @user).pre_factura_items),
                 huella(r.pre_factura.pre_factura_items)
    assert_includes r.flete_de(prepagada).concepto, "PREPAGADO EN MIAMI"
  end

  test "una tanda rechazada cobra solo las cajas que se eligieron" do
    tarifa_cer
    normal = caja(peso: 5)
    otra = caja(peso: 7)
    prepagada = caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo")
    medir([ normal, otra, prepagada ], { peso: "8" })

    r = armar(normal)

    assert_equal [ normal.id ], r.pre_factura.pre_factura_items.map(&:paquete_id)
  end

  test "una tanda con tarifas distintas va por paquete, cada caja con la suya" do
    tarifa_cer
    tarifa_cer(proveedor: proveedores(:Amazon), precio_libra: 3.00)
    amazon = caja(proveedor: proveedores(:Amazon), peso: 4)
    otra = caja(peso: 4)
    bulto, = medir([ amazon, otra ], { peso: "8" })

    r = armar(amazon, otra)

    assert_match(/tarifas distintas/, r.rechazos[bulto.sesion])
    assert_equal huella(PreFactura.build_from_paquetes(@cliente, [ amazon.id, otra.id ], user: @user).pre_factura_items),
                 huella(r.pre_factura.pre_factura_items)
    assert_not_equal r.flete_de(amazon).precio_libra, r.flete_de(otra).precio_libra
  end

  test "una caja cuya tanda se midió de nuevo y ya no tiene volúmenes va por paquete, sin motivo que mostrar" do
    tarifa_cer
    suelta = caja(peso: 3)
    suelta.update_columns(medicion_sesion: "SESION-QUE-YA-NO-EXISTE")

    r = armar(suelta)

    assert_empty r.rechazos
    assert_equal [ "manual" ], r.pre_factura.pre_factura_items.map(&:origen)
  end

  # ── Los cargos automáticos: una vez por caja ────────────────────────────

  test "la recolecta y el cambio de servicio salen una vez, vaya la caja por volumen o por paquete" do
    tarifa_cer
    cambio_de_servicio
    en_tanda_recolecta = caja(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD")
    en_tanda_cambio = caja(solicito_cambio_servicio: true)
    medir([ en_tanda_recolecta, en_tanda_cambio ], { peso: "8" })
    suelta_recolecta = caja(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD")
    suelta_cambio = caja(solicito_cambio_servicio: true)

    r = armar(en_tanda_recolecta, suelta_recolecta, suelta_cambio) # la tanda llega por una caja

    assert_equal [ en_tanda_recolecta.id, suelta_recolecta.id ].sort,
                 de_origen(r.pre_factura, "auto_recolecta").map(&:paquete_id).sort
    assert_equal [ en_tanda_cambio.id, suelta_cambio.id ].sort,
                 de_origen(r.pre_factura, "auto_servicio_extra").map(&:paquete_id).sort
  end

  # ── Las tres cosas en el mismo documento ────────────────────────────────

  test "tanda por volumen, tanda rechazada y paquete suelto: cada uno con su motor, y el ISV sobre la suma" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cambio_de_servicio
    medidas = [ caja(peso: 2), caja(peso: 2, recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD") ]
    medida, = medir(medidas, { peso: "12.3" })
    rechazadas = [ caja(peso: 6), caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo") ]
    rechazada, = medir(rechazadas, { peso: "9" })
    suelta = caja(peso: 0.5, solicito_cambio_servicio: true)

    r = armar(medidas.first, *rechazadas, suelta)

    assert_equal [ medida.sesion ], r.por_volumen
    assert_equal [ rechazada.sesion ], r.rechazos.keys

    f9 = por_volumen(medida.sesion)
    a_mano = PreFactura.build_from_paquetes(@cliente, [ *rechazadas, suelta ].map(&:id), user: @user)
    assert_equal huella(f9.pre_factura_items + a_mano.pre_factura_items), huella(r.pre_factura.pre_factura_items)

    subtotal = (f9.pre_factura_items + a_mano.pre_factura_items).sum { |i| i.subtotal.to_d }
    impuesto = (subtotal * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP)
    r.pre_factura.save!
    assert_equal [ subtotal, impuesto, subtotal + impuesto ],
                 [ r.pre_factura.subtotal, r.pre_factura.impuesto, r.pre_factura.total ]
    assert_equal [ rechazadas.last ], r.pre_factura.prepagados_miami_detected
    assert_equal (medidas + rechazadas + [ suelta ]).map(&:id).sort, r.pre_factura.paquetes.map(&:id).sort
  end
end
