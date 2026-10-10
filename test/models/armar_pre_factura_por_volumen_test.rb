require "test_helper"

# PR-P.1 · La línea de la factura es el volumen (Fase 14, `C27-10`, `RP-41`).
#
# Lo que estos tests cuidan es la plata: el volumen se cobra con **el mismo
# motor** que una caja suelta —redondeo → escalón → mínimo → ISV—, un volumen
# de tres cajas cobra **un** mínimo, y el resto del documento (`confirmar!`,
# `facturar!`, `anular!`) sigue encontrando las tres cajas.
class ArmarPreFacturaPorVolumenTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    Tarifa.delete_all
  end

  def caja(cliente: @cliente, peso: 2, **extra)
    Paquete.create!(tracking: "1ZVOL#{SecureRandom.hex(5).upcase}", cliente: cliente,
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", peso: peso, **extra)
  end

  def medir(cajas, *volumenes)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  def armar(*bultos) = ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: bultos.map(&:sesion).uniq, user: @user)

  def a_lps(usd) = CurrencyAware.convertir(usd, de: "USD", a: "LPS")
  def volumenes(pf) = pf.pre_factura_items.select { |i| i.origen == "volumen" }
  def cajas_de(pf) = pf.pre_factura_items.select { |i| i.origen == "caja_del_volumen" }

  def tarifa_cer(**extra)
    Tarifa.create!({ tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD" }.merge(extra))
  end

  # ── Un mínimo por volumen, no por caja ──────────────────────────────────

  test "un volumen de tres cajas es UNA línea de flete con UN mínimo, y las cajas en cero" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = 3.times.map { caja(peso: 1) }
    bulto, = medir(cajas, { peso: "3" }) # 3 lb × 4.50 = 13.50 < 20

    pf = armar(bulto)

    assert_equal 1, volumenes(pf).size, "una línea por volumen"
    linea = volumenes(pf).first
    assert_equal bulto, linea.bulto
    assert_nil linea.paquete
    assert linea.minimo_aplicado
    assert_equal a_lps(20.00), linea.subtotal, "un mínimo, no tres"
    assert_includes linea.concepto, "mínimo de servicio"
    assert_includes linea.concepto, "3 cajas"

    assert_equal cajas.map(&:id).sort, cajas_de(pf).map(&:paquete_id).sort
    assert cajas_de(pf).all? { |i| i.subtotal.zero? && i.minimo_aplicado && i.peso_cobrar.nil? && i.precio_libra.nil? }
    assert cajas_de(pf).all? { |i| i.bulto == bulto }, "la caja sabe su tanda por el volumen"

    pf.save!
    assert_equal a_lps(20.00), pf.reload.subtotal
    assert_equal (a_lps(20.00) * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP), pf.impuesto
  end

  test "cada volumen de la tanda tiene su línea, con su escalón y su mínimo" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = 4.times.map { caja }
    uno, dos = medir(cajas, { peso: "2" }, { peso: "30" })

    lineas = volumenes(armar(uno))

    assert_equal [ uno, dos ], lineas.map(&:bulto)
    assert_equal [ true, false ], lineas.map(&:minimo_aplicado)
    assert_equal [ a_lps(20.00), (BigDecimal("30") * a_lps(4.50)).round(2) ], lineas.map(&:subtotal)
    assert_includes lineas.first.concepto, "Volumen 1 de 2"
    assert_equal 4, cajas_de(armar(uno)).size, "las cajas son de la tanda: van una vez, no por volumen"
  end

  # ── Paridad: el mismo motor que la caja suelta ──────────────────────────

  test "el volumen cobra lo mismo que CotizadorFlete y que build_from_paquetes para el mismo peso" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    [ "1.3", "37.2" ].each do |peso|
      bulto, = medir([ caja, caja ], { peso: peso })
      linea = volumenes(armar(bulto)).first

      cot = CotizadorFlete.call(tipo_envio: tipo_envios(:cer), cliente: @cliente, peso: bulto.peso_cobrar)
      suelta = caja(peso: peso.to_d)
      flete = PreFactura.build_from_paquetes(@cliente, [ suelta.id ], user: @user).pre_factura_items.first

      assert_equal cot.subtotal, linea.subtotal, "#{peso} lb: distinto del cotizador"
      assert_equal flete.subtotal, linea.subtotal, "#{peso} lb: distinto de una caja suelta"
      assert_equal flete.peso_cobrar, linea.peso_cobrar
      assert_equal flete.precio_libra, linea.precio_libra
      assert_equal flete.minimo_aplicado, linea.minimo_aplicado
    end
  end

  test "lee el peso de Medición, no el de Miami" do
    tarifa_cer
    cajas = [ caja(peso: 50), caja(peso: 50) ]
    bulto, = medir(cajas, { peso: "12" })

    assert_equal (BigDecimal("12") * a_lps(4.50)).round(2), volumenes(armar(bulto)).first.subtotal
  end

  test "sin tarifa: UNA línea que lo grita, no una por caja" do
    bulto, = medir([ caja, caja, caja ], { peso: "10" })

    pf = armar(bulto)
    avisos = pf.pre_factura_items.select { |i| i.concepto.start_with?("⚠ SIN TARIFA CARGADA") }

    assert_equal 1, avisos.size
    assert_equal 0, avisos.first.subtotal
    assert_equal 3, cajas_de(pf).size
    assert pf.save
  end

  # ── El resto del documento sigue igual ──────────────────────────────────

  test "confirmar y facturar alcanzan las tres cajas, y la factura conserva el mínimo y el volumen" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = 3.times.map { caja }
    bulto, = medir(cajas, { peso: "3" })
    pf = armar(bulto)
    pf.save!

    assert_equal [ pf.id ] * 3, cajas.map { |c| c.reload.pre_factura_id }, "vincular_paquetes las reserva"
    assert pf.confirmar!
    assert_equal [ "disponible_entrega" ] * 3, cajas.map { |c| c.reload.estado }

    venta = pf.facturar!
    assert_equal [ venta.id ] * 3, cajas.map { |c| c.reload.venta_id }
    flete = venta.venta_items.find { |i| i.bulto_id == bulto.id && i.paquete_id.nil? }
    assert flete.minimo_aplicado
    assert_equal a_lps(20.00), flete.subtotal, "VentaItem no recalcula el mínimo"
    assert_equal 3, venta.venta_items.count { |i| i.bulto_id == bulto.id && i.paquete_id.present? }
    assert_equal pf.total, venta.total
  end

  test "anular suelta las tres cajas" do
    tarifa_cer
    cajas = 3.times.map { caja }
    bulto, = medir(cajas, { peso: "8" })
    pf = armar(bulto)
    pf.save!

    assert pf.anular!
    assert_equal [ nil ] * 3, cajas.map { |c| c.reload.pre_factura_id }
    assert_equal 3, Paquete.facturables.where(id: cajas.map(&:id)).count
  end

  test "los cargos automáticos siguen saliendo por caja" do
    tarifa_cer
    ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.precio_venta = 15
      s.moneda = "USD"
      s.costo = 0
    end
    con_recolecta = caja(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD")
    con_cambio = caja(solicito_cambio_servicio: true)
    bulto, = medir([ con_recolecta, con_cambio, caja ], { peso: "8" })

    pf = armar(bulto)

    assert_equal [ con_recolecta.id ], pf.pre_factura_items.select { |i| i.origen == "auto_recolecta" }.map(&:paquete_id)
    assert_equal [ con_cambio.id ], pf.pre_factura_items.select { |i| i.origen == "auto_servicio_extra" }.map(&:paquete_id)
  end

  # ── Volver a medir un volumen cobrado ───────────────────────────────────

  test "un volumen en una pre-factura no se borra, y medir de nuevo su tanda lo dice" do
    tarifa_cer
    cajas = [ caja, caja ]
    bulto, = medir(cajas, { peso: "8" })
    pf = armar(bulto)
    pf.save!

    assert_not bulto.destroy, "un volumen cobrado no se borra"
    assert bulto.errors.any?

    error = assert_raises(MedirBulto::NoSePuede) do
      MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: "9" } ],
                                           reemplaza_sesion: bulto.sesion)
    end
    assert_includes error.message, pf.numero
    assert Bulto.exists?(bulto.id)
    assert_equal [ bulto.sesion ] * 2, cajas.map { |c| c.reload.medicion_sesion }, "nada cambió"
  end

  test "con la pre-factura anulada se mide de nuevo, y el volumen viejo queda para el documento anulado" do
    tarifa_cer
    cajas = [ caja, caja ]
    viejo, = medir(cajas, { peso: "8" })
    pf = armar(viejo)
    pf.save!
    pf.anular!

    nuevo, = MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: "9" } ],
                                                  reemplaza_sesion: viejo.sesion)

    assert Bulto.exists?(viejo.id), "el documento anulado lo sigue nombrando"
    assert_equal [ nuevo.sesion ] * 2, cajas.map { |c| c.reload.medicion_sesion }
    linea = volumenes(armar(nuevo)).first
    assert_equal nuevo, linea.bulto, "lo que se cobra es la tanda actual"
    assert_equal (BigDecimal("9") * a_lps(4.50)).round(2), linea.subtotal
  end

  # ── Lo que no se cobra a medias ─────────────────────────────────────────

  test "si una caja de la tanda ya está en otra pre-factura, no se arma" do
    tarifa_cer
    cajas = [ caja, caja ]
    bulto, = medir(cajas, { peso: "8" })
    PreFactura.build_from_paquetes(@cliente, [ cajas.first.id ], user: @user).save!

    error = assert_raises(ArmarPreFacturaPorVolumen::NoSePuede) { armar(bulto) }
    assert_includes error.message, cajas.first.numero_recepcion_visible
  end

  # ── PR-P.11a · Prepagado en Miami (RP-89, provisorio) ───────────────────
  #
  # Lo que cobraba la puerta a mano por paquete —US$1 por caja, más ISV— lo
  # cobra ahora el escaneo, con el volumen en L. 0.00 y su peso a la vista.

  def prepagada(**extra) = caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo", **extra)
  def simbolicos(pf) = pf.pre_factura_items.select { |i| i.origen == "manual" && i.concepto.include?("PREPAGADO EN MIAMI") }

  test "una tanda toda prepagada: el volumen en cero con su peso, y US$1 por caja suelto" do
    tarifa_cer(minimo_monto: 20.00, minimo_moneda: "USD")
    cajas = [ prepagada, prepagada ]
    bulto, = medir(cajas, { peso: "8" })

    pf = armar(bulto)

    linea = volumenes(pf).first
    assert_equal 1, volumenes(pf).size
    assert_equal bulto, linea.bulto
    assert_equal 0, linea.subtotal, "ya se pagó en Miami: el flete no se cobra"
    assert_equal BigDecimal("0"), linea.precio_libra
    assert linea.minimo_aplicado, "nadie le recalcula peso × precio"
    assert_equal bulto.peso_cobrar, linea.peso_cobrar, "el peso del volumen queda a la vista"
    assert_includes linea.concepto, "PREPAGADO EN MIAMI"
    assert_equal 2, cajas_de(pf).size
    assert cajas_de(pf).all? { |i| i.subtotal.zero? }

    simbolos = simbolicos(pf)
    assert_equal cajas.map(&:id).sort, simbolos.map(&:paquete_id).sort, "uno por caja"
    assert simbolos.all? { |i| i.subtotal == a_lps(PreFactura::PREPAGADO_MIAMI_SIMBOLICO) }, "US$1 → L con la tasa"
    assert simbolos.all? { |i| i.bulto.nil? && i.peso_cobrar.nil? && i.precio_libra.nil? && i.minimo_aplicado },
           "suelto y sin peso: si no, LineasPorVolumen lo esconde y la etiqueta cuenta las libras dos veces"
    assert_equal cajas.map(&:id).sort, pf.prepagados_miami_detected.map(&:id).sort

    pf.save!
    simbolo = a_lps(PreFactura::PREPAGADO_MIAMI_SIMBOLICO)
    assert_equal simbolo * 2, pf.reload.subtotal, "el dólar sobrevive al guardar"
    assert_equal (simbolo * 2 * IsvAware.rate).round(2, BigDecimal::ROUND_HALF_UP), pf.impuesto, "US$1 + ISV"
    assert_equal pf.subtotal + pf.impuesto, pf.total
  end

  test "la tanda prepagada cobra lo mismo que la puerta a mano por paquete" do
    tarifa_cer
    cajas = [ prepagada, prepagada(recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD") ]
    bulto, = medir(cajas, { peso: "8" })

    por_volumen = armar(bulto).tap(&:calcular_totales)
    por_paquete = PreFactura.build_from_paquetes(@cliente, cajas.map(&:id), user: @user).tap(&:calcular_totales)

    assert_equal por_paquete.subtotal, por_volumen.subtotal
    assert_equal por_paquete.total, por_volumen.total
    assert_equal [ cajas.last.id ], por_volumen.pre_factura_items.select { |i| i.origen == "auto_recolecta" }.map(&:paquete_id),
                 "los cobros automáticos siguen por caja"
  end

  test "la etiqueta de entrega cuenta el peso del volumen una vez, no el de los simbólicos" do
    tarifa_cer
    bulto, = medir([ prepagada, prepagada ], { peso: "8" })
    pf = armar(bulto)
    pf.save!

    assert_equal bulto.peso_cobrar, EtiquetaDeEntrega.new(pf.reload).libras
  end

  test "una tanda que mezcla prepagadas y no prepagadas no se arma: se mide de nuevo separada" do
    tarifa_cer
    normal = caja
    medida_antes = caja
    bulto, = medir([ normal, medida_antes ], { peso: "8" })
    # Medición ya no deja juntarlas (`PuedenIrJuntas#prepago_mezclado`): esto
    # es una tanda medida antes de PR-P.11a.
    medida_antes.update_columns(prepagado_miami: true, prepagado_miami_metodo: "efectivo")

    error = assert_raises(ArmarPreFacturaPorVolumen::NoSePuede) { armar(bulto) }
    assert_includes error.message, "prepagada en Miami"
    assert_includes error.message, "medila de nuevo separando las prepagadas"
    assert_not_includes error.message, "A mano (excepciones)", "PR-P.11a: la puerta a mano se va"
  end

  test "las cajas de otro cliente no entran" do
    tarifa_cer
    bulto, = medir([ caja, caja ], { peso: "8" })

    assert_raises(ArmarPreFacturaPorVolumen::NoSePuede) do
      ArmarPreFacturaPorVolumen.call(cliente: clientes(:maria), sesiones: [ bulto.sesion ])
    end
  end

  test "si las cajas cotizarían con tarifas distintas, no elige una" do
    tarifa_cer
    tarifa_cer(proveedor: proveedores(:Amazon), precio_libra: 3.00)
    de_amazon = caja
    bulto, = medir([ de_amazon, caja ], { peso: "8" })
    # PR-P.11a · Medición ya no las junta (`PuedenIrJuntas#otra_tarifa`): ésta
    # es una tanda medida antes, y esto la última red.
    de_amazon.update_columns(proveedor_id: proveedores(:Amazon).id)

    error = assert_raises(ArmarPreFacturaPorVolumen::NoSePuede) { armar(bulto) }
    assert_includes error.message, "tarifas distintas"
    assert_includes error.message, "medila de nuevo separándolas"
  end
end
