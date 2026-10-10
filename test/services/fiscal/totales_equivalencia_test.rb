require "test_helper"

# PR-F2.1 · Fase 15 · El corazón del PR: los totales que calcula la gema
# (`Fiscal::Totales`) son **idénticos**, campo por campo, a los que calculaba
# la app antes. Es plata: si un solo caso diera distinto, no se ajusta ninguna
# de las dos fórmulas — se para y lo decide el dueño.
#
# `formula_vieja` es una copia **congelada** de `PreFactura#calculate_totals`
# como estaba en staging antes de F2.1 (8f34e61); `formula_vieja_sin_descuento`
# la de `NotaCredito`/`NotaDebito`/`Cotizacion`. No se tocan: son la referencia.
class Fiscal::TotalesEquivalenciaTest < ActiveSupport::TestCase
  # La tasa con la que corría la fórmula vieja: `empresas.isv_rate` (fixture y
  # seeds en 0.15).
  ISV_VIEJO = BigDecimal("0.15")

  # ── La referencia congelada ─────────────────────────────────────────────

  # Copia de `PreFactura#calculate_totals` (y su gemelo de `Venta`) en staging.
  def formula_vieja(items)
    vivos = items.reject(&:marked_for_destruction?)
    sub  = vivos.sum { |i| i.subtotal.to_d }
    desc = vivos.sum { |i| i.descuento_monto.to_d }
    base = sub - desc

    impuesto = (base * ISV_VIEJO).round(2, BigDecimal::ROUND_HALF_UP)
    { subtotal: sub, descuento: desc, impuesto: impuesto,
      total: (base + impuesto).round(2, BigDecimal::ROUND_HALF_UP) }
  end

  # Copia de `NotaCredito#calculate_totals` (y `NotaDebito`, `Cotizacion`).
  def formula_vieja_sin_descuento(items)
    sub = items.reject(&:marked_for_destruction?).sum { |i| i.subtotal.to_d }
    impuesto = (sub * ISV_VIEJO).round(2, BigDecimal::ROUND_HALF_UP)
    { subtotal: sub, impuesto: impuesto, total: (sub + impuesto).round(2) }
  end

  CAMPOS = %i[subtotal descuento impuesto total].freeze

  # Compara campo por campo, con `==` de BigDecimal y también el texto a dos
  # decimales —lo que se imprime—, que no admite ni un centavo de diferencia.
  def assert_equivalente(items, moneda: "LPS", sin_descuento: false, caso: "")
    vivos = items.reject(&:marked_for_destruction?)
    vieja = sin_descuento ? formula_vieja_sin_descuento(items) : formula_vieja(items)
    nueva = Fiscal::Totales.calcular(vivos, moneda: moneda)

    (sin_descuento ? CAMPOS - [ :descuento ] : CAMPOS).each do |campo|
      # (La fórmula vieja, con cero líneas, da el Integer 0: `[].sum`.)
      assert_equal vieja[campo], nueva[campo], "#{caso} · #{campo}: vieja #{vieja[campo].to_d.to_s('F')} ≠ gema #{nueva[campo].to_s('F')}"
      assert_equal format("%.2f", vieja[campo]), format("%.2f", nueva[campo]), "#{caso} · #{campo} impreso"
    end
    nueva
  end

  def linea(subtotal, descuento: "0", concepto: "Flete CER")
    PreFacturaItem.new(concepto: concepto, subtotal: BigDecimal(subtotal.to_s),
                       descuento_monto: BigDecimal(descuento.to_s), origen: "manual")
  end

  setup do
    # La tasa de Yusef (project_tasa_cambio_fija_27_10). La fixture trae 24.85.
    Configuracion.set("tasa_cambio", "27.10", tipo: "decimal")
    @cliente = clientes(:juan)
  end

  # ── Las fixtures ────────────────────────────────────────────────────────
  # Las de pre-factura no traen líneas (dan 0 = 0); las de venta, notas y
  # cotización sí. Se compara la fórmula y también lo que el modelo guarda.

  test "cada pre-factura de las fixtures" do
    assert PreFactura.exists?
    PreFactura.find_each do |pf|
      assert_equivalente(pf.pre_factura_items.to_a, moneda: pf.moneda, caso: pf.numero)
      pf.save!(validate: false)
      vieja = formula_vieja(pf.pre_factura_items.reload.to_a)
      CAMPOS.each { |c| assert_equal vieja[c], pf.reload.public_send(c), "#{pf.numero} guardada · #{c}" }
    end
  end

  test "cada venta, nota y cotización de las fixtures" do
    { Venta => :venta_items, NotaCredito => :nota_credito_items,
      NotaDebito => :nota_debito_items, Cotizacion => :cotizacion_items }.each do |modelo, lineas|
      assert modelo.exists?, modelo.name
      modelo.find_each do |doc|
        items = doc.public_send(lineas).to_a
        assert items.any?, "#{doc.numero} sin líneas: la fixture no prueba nada"
        sin_desc = modelo != Venta
        assert_equivalente(items, moneda: doc.moneda, sin_descuento: sin_desc, caso: doc.numero)

        doc.save!(validate: false)
        doc.reload
        vieja = sin_desc ? formula_vieja_sin_descuento(items) : formula_vieja(items)
        vieja.each_key { |c| assert_equal vieja[c], doc.public_send(c), "#{doc.numero} guardado · #{c}" }
      end
    end
  end

  # ── La cadena de cobro de verdad: mínimos, SIN TARIFA, cargos automáticos ─

  def paquete(peso:, tipo: :cer, **extra)
    Paquete.create!(cliente: @cliente, sucursal: sucursales(:miami), estado: "disponible_entrega",
                    tipo_envio: tipo_envios(tipo), tracking: "F21-#{SecureRandom.hex(4)}",
                    peso: peso, **extra)
  end

  def pre_factura_de(*paquetes)
    PreFactura.build_from_paquetes(@cliente, paquetes.map(&:id))
  end

  def tarifa_cer_con_minimo_de_yusef
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 173.91, minimo_moneda: "LPS")
  end

  test "CER bajo el mínimo: 173.91 neto → L 200.00 (RP-08)" do
    tarifa_cer_con_minimo_de_yusef
    pf = pre_factura_de(paquete(peso: 1))

    t = assert_equivalente(pf.pre_factura_items.to_a, caso: "mínimo")
    assert_equal BigDecimal("173.91"), t[:subtotal]
    assert_equal BigDecimal("26.09"), t[:impuesto]
    assert_equal BigDecimal("200.00"), t[:total]

    pf.save!
    assert_equal BigDecimal("200.00"), pf.reload.total
  end

  test "dos mínimos: 347.82 → L 399.99, no 400.00" do
    tarifa_cer_con_minimo_de_yusef
    pf = pre_factura_de(paquete(peso: 1), paquete(peso: 1))

    t = assert_equivalente(pf.pre_factura_items.to_a, caso: "dos mínimos")
    assert_equal BigDecimal("347.82"), t[:subtotal]
    assert_equal BigDecimal("52.17"), t[:impuesto]
    assert_equal BigDecimal("399.99"), t[:total]
  end

  test "CER sobre el mínimo: 1.5 lb → 182.93 → L 210.37 (la cuenta de Yusef)" do
    tarifa_cer_con_minimo_de_yusef
    pf = pre_factura_de(paquete(peso: 1.5))

    t = assert_equivalente(pf.pre_factura_items.to_a, caso: "1.5 lb")
    assert_equal BigDecimal("182.93"), t[:subtotal]
    assert_equal BigDecimal("210.37"), t[:total]
  end

  # D3 con la cadena de verdad: cada caja cobra 182.925 → 182.93 en su línea.
  # Si la gema recibiera cantidad = peso, redondearía la suma: 365.85.
  test "dos CER de 1.5 lb: 182.93 + 182.93 = 365.86 → L 420.74" do
    tarifa_cer_con_minimo_de_yusef
    pf = pre_factura_de(paquete(peso: 1.5), paquete(peso: 1.5))

    t = assert_equivalente(pf.pre_factura_items.to_a, caso: "dos de 1.5 lb")
    assert_equal BigDecimal("365.86"), t[:subtotal]
    assert_equal BigDecimal("54.88"), t[:impuesto]
    assert_equal BigDecimal("420.74"), t[:total]
  end

  test "«⚠ SIN TARIFA» en 0.00, junto a una línea con precio" do
    tarifa_cer_con_minimo_de_yusef
    pf = pre_factura_de(paquete(peso: 3), paquete(peso: 2, tipo: :cem))

    sin_tarifa = pf.pre_factura_items.find { |i| i.concepto.include?("SIN TARIFA") }
    assert sin_tarifa, "el CEM no tiene tarifa: la línea va en cero y lo grita"
    assert_equal 0, sin_tarifa.subtotal
    assert_equivalente(pf.pre_factura_items.to_a, caso: "sin tarifa")

    solo = pre_factura_de(paquete(peso: 2, tipo: :cem))
    t = assert_equivalente(solo.pre_factura_items.to_a, caso: "solo sin tarifa")
    assert_equal 0, t[:total]
  end

  test "recolecta y CAMBIO_SERVICIO automáticos, con el flete" do
    tarifa_cer_con_minimo_de_yusef
    ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.precio_venta = 15
      s.moneda = "USD"
      s.costo = 0
    end
    pf = pre_factura_de(paquete(peso: 7.3, recolecta_solicitada: true, recolecta_monto: 35.0,
                                recolecta_moneda: "USD", solicito_cambio_servicio: true))

    origenes = pf.pre_factura_items.map(&:origen).sort
    assert_equal %w[auto_recolecta auto_servicio_extra manual], origenes
    assert_equivalente(pf.pre_factura_items.to_a, caso: "cobros automáticos")

    pf.save!
    vieja = formula_vieja(pf.pre_factura_items.reload.to_a)
    CAMPOS.each { |c| assert_equal vieja[c], pf.reload.public_send(c), "guardada · #{c}" }
  end

  # ── Por volumen (Fase 14): una línea de flete y las cajas en 0.00 ────────

  def caja(peso: 1, **extra)
    Paquete.create!(tracking: "1ZF21#{SecureRandom.hex(5).upcase}", cliente: @cliente,
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", peso: peso, **extra)
  end

  def armar_volumen(cajas, peso)
    user = users(:supervisor_prefactura)
    bulto, = MedirBulto.new(user: user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: peso } ])
    ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: [ bulto.sesion ], user: user)
  end

  test "un volumen y sus tres cajas en 0.00 (ArmarPreFacturaPorVolumen)" do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    pf = armar_volumen(3.times.map { caja }, "11.2")

    assert_equal 1, pf.pre_factura_items.count { |i| i.origen == "volumen" }
    cajas = pf.pre_factura_items.select { |i| i.origen == "caja_del_volumen" }
    assert_equal 3, cajas.size
    assert cajas.all? { |i| i.subtotal.zero? }
    assert_equivalente(pf.pre_factura_items.to_a, caso: "volumen")

    pf.save!
    vieja = formula_vieja(pf.pre_factura_items.reload.to_a)
    CAMPOS.each { |c| assert_equal vieja[c], pf.reload.public_send(c), "volumen guardado · #{c}" }
  end

  test "prepagado en Miami: el simbólico US$1 → L 27.10 en un documento en lempiras" do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    prepagadas = 2.times.map { caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo") }
    pf = armar_volumen(prepagadas, "8")

    simbolos = pf.pre_factura_items.select { |i| i.concepto.include?("PREPAGADO EN MIAMI") && i.origen == "manual" }
    assert_equal 2, simbolos.size
    assert simbolos.all? { |i| i.subtotal == BigDecimal("27.10") }, "US$1 a 27.10"

    t = assert_equivalente(pf.pre_factura_items.to_a, caso: "prepagado")
    assert_equal BigDecimal("54.20"), t[:subtotal]
    assert_equal BigDecimal("8.13"), t[:impuesto]
    assert_equal BigDecimal("62.33"), t[:total]
  end

  # ── Descuentos ──────────────────────────────────────────────────────────

  test "descuento por porcentaje" do
    a = linea("182.93")
    a.aplicar_descuento_porcentaje(10) # 18.293 → 18.29
    assert_equal BigDecimal("18.29"), a.descuento_monto
    t = assert_equivalente([ a, linea("121.95") ], caso: "10 %")
    assert_equal BigDecimal("286.59"), t[:base]
  end

  test "descuento por monto" do
    a = linea("399.99")
    a.aplicar_descuento_monto("25.50")
    assert_equivalente([ a, linea("27.10"), linea("0.00") ], caso: "monto")
  end

  test "una línea con 100 % de descuento" do
    a = linea("173.91")
    a.aplicar_descuento_porcentaje(100)
    t = assert_equivalente([ a ], caso: "100 % sola")
    assert_equal 0, t[:total]

    b = linea("200.00")
    b.aplicar_descuento_porcentaje(100)
    assert_equivalente([ b, linea("57.33", descuento: "0.01") ], caso: "100 % con otra")
  end

  # ── Un documento en dólares ─────────────────────────────────────────────

  test "documento en USD: líneas en dólares, tasa 27.10" do
    pf = PreFactura.new(cliente: @cliente, moneda: "USD", fecha_trabajo: Date.current)
    pf.pre_factura_items.build(concepto: "Flete CER", peso_cobrar: 1.5, precio_libra: 4.50, origen: "manual")
    pf.pre_factura_items.build(concepto: "Flete CEM", peso_cobrar: 7.5, precio_libra: 2.25, origen: "manual")
    pf.pre_factura_items.build(concepto: "Recolecta", subtotal: 35, minimo_aplicado: true, origen: "auto_recolecta")
    pf.pre_factura_items.build(concepto: "Prepagado", subtotal: 1, minimo_aplicado: true, origen: "manual",
                               descuento_monto: BigDecimal("0.33"))
    pf.valid? # corre el `peso × precio` de cada línea, como antes de guardar

    t = assert_equivalente(pf.pre_factura_items.to_a, moneda: "USD", caso: "USD")
    assert_equal "USD", t[:buckets].first.base.currency

    pf.save!
    assert_equal BigDecimal("27.10"), pf.tasa_cambio_aplicada
    vieja = formula_vieja(pf.pre_factura_items.reload.to_a)
    CAMPOS.each { |c| assert_equal vieja[c], pf.reload.public_send(c), "USD guardada · #{c}" }
  end

  # ── Medio centavo: la regla del contador (half-up) ──────────────────────

  test "bordes de medio centavo en el ISV" do
    {
      "0.10" => "0.02",  # 0.015  → sube
      "1.70" => "0.26",  # 0.255  → sube
      "0.30" => "0.05",  # 0.045  → sube
      "0.03" => "0.00",  # 0.0045 → baja
      "182.93" => "27.44", # 27.4395 → baja
      "3.90" => "0.59"   # 0.585 → sube
    }.each do |base, isv|
      t = assert_equivalente([ linea(base) ], caso: "base #{base}")
      assert_equal BigDecimal(isv), t[:impuesto], "ISV de #{base}"
      t = assert_equivalente([ linea(base) ], moneda: "USD", caso: "USD base #{base}")
      assert_equal BigDecimal(isv), t[:impuesto], "ISV de #{base} en USD"
    end

    # El medio centavo que sale DESPUÉS del descuento: 2.00 − 0.30 = 1.70.
    t = assert_equivalente([ linea("2.00", descuento: "0.30") ], caso: "medio centavo con descuento")
    assert_equal BigDecimal("0.26"), t[:impuesto]
  end

  test "documento vacío: todo en cero, en las dos monedas" do
    %w[LPS USD].each do |moneda|
      t = assert_equivalente([], moneda: moneda, caso: "vacío #{moneda}")
      assert_equal 0, t[:total]
    end
  end

  test "las líneas marcadas para borrar no suman" do
    a = linea("500.00")
    a.mark_for_destruction
    assert_equivalente([ a, linea("10.00") ], caso: "marked_for_destruction")
  end

  # ── D3: cantidad 1 y el subtotal de la línea como precio ────────────────

  test "guarda: el adaptador siempre pasa cantidad 1 y el subtotal ya redondeado" do
    pf = PreFactura.new(cliente: @cliente, moneda: "LPS", fecha_trabajo: Date.current)
    2.times { pf.pre_factura_items.build(concepto: "Flete CER", peso_cobrar: 1.5, precio_libra: 121.95, origen: "manual") }
    pf.valid?
    items = pf.pre_factura_items.to_a
    assert items.all? { |i| i.subtotal == BigDecimal("182.93") }, "182.925 → 182.93 por línea"

    t = Fiscal::Totales.calcular(items, moneda: "LPS")
    assert_equal 2, t[:lineas].size
    t[:lineas].zip(items).each do |gema, item|
      assert_equal BigDecimal("1"), gema.quantity, "D3: cantidad 1, nunca el peso"
      assert_equal item.subtotal, gema.unit_price.amount, "D3: el precio es el subtotal de la línea"
    end
    # Con cantidad = peso la gema sumaría 365.85: el centavo que D3 protege.
    assert_equal BigDecimal("365.86"), t[:subtotal]
    assert_equivalente(items, caso: "D3")
  end

  # La equivalencia descansa en esto: la columna es numeric(10,2) y Active
  # Record redondea al asignar (half-up), así que a la gema nunca le llega un
  # tercer decimal. Si alguien cambiara la escala, este test avisa primero.
  test "precondición: la línea ya llega redondeada a dos decimales, half-up" do
    assert_equal BigDecimal("1.01"), PreFacturaItem.new(subtotal: "1.005").subtotal
    assert_equal BigDecimal("1.00"), PreFacturaItem.new(subtotal: "1.004").subtotal
    assert_equal BigDecimal("0.02"), PreFacturaItem.new(descuento_monto: "0.015").descuento_monto
    assert_equal BigDecimal("1.01"), NotaCreditoItem.new(subtotal: "1.005").subtotal
  end

  test "todas las líneas de cobro son gravadas al 15 % (la costura de F3)" do
    [ PreFacturaItem, VentaItem, NotaCreditoItem, NotaDebitoItem, CotizacionItem ].each do |modelo|
      assert_equal :gravado_15, modelo.new.tratamiento_fiscal, modelo.name
    end
    assert_equal IsvAware.rate, Invoicehn::TaxTreatment.fetch(:gravado_15).rate
  end

  test "LPS de la app es HNL en la gema, en un solo lugar" do
    assert_equal({ "LPS" => "HNL", "USD" => "USD" }, Fiscal::Totales::MONEDA_GEMA)
    assert_equal "HNL", Fiscal::Totales.calcular([ linea("1.00") ], moneda: "LPS")[:buckets].first.isv.currency
    assert_raises(KeyError) { Fiscal::Totales.calcular([ linea("1.00") ], moneda: "EUR") }
  end

  # ── Mil documentos al azar ──────────────────────────────────────────────
  # Semilla fija: si un día falla, el mismo documento sale de nuevo.

  test "1000 documentos al azar dan idéntico, campo por campo" do
    rng = Random.new(2026)
    diferencias = []
    lineas_probadas = 0

    1000.times do |n|
      moneda = rng.rand(2).zero? ? "LPS" : "USD"
      items = Array.new(rng.rand(1..30)) do |k|
        centavos = rng.rand(0..500_000) # 0.00 … 5,000.00
        desc =
          case rng.rand(4)
          when 0 then rng.rand(0..centavos) # cualquier descuento ≤ subtotal
          when 1 then centavos.zero? ? 0 : rng.rand(1..[ centavos, 10 ].min) # centavos sueltos
          else 0
          end
        PreFacturaItem.new(concepto: "L#{k}", subtotal: BigDecimal(centavos) / 100,
                           descuento_monto: BigDecimal(desc) / 100, origen: "manual")
      end
      lineas_probadas += items.size

      vieja = formula_vieja(items)
      nueva = Fiscal::Totales.calcular(items, moneda: moneda)
      CAMPOS.each do |c|
        next if vieja[c] == nueva[c]

        diferencias << "doc #{n} (#{moneda}, #{items.size} líneas) #{c}: vieja #{vieja[c].to_s('F')} gema #{nueva[c].to_s('F')} " \
                       "líneas=#{items.map { |i| [ i.subtotal.to_s('F'), i.descuento_monto.to_s('F') ] }.inspect}"
      end

      # El mismo documento como nota o cotización (sin descuento).
      notas = items.map { |i| NotaCreditoItem.new(concepto: i.concepto, subtotal: i.subtotal) }
      vieja = formula_vieja_sin_descuento(notas)
      nueva = Fiscal::Totales.calcular(notas, moneda: moneda)
      %i[subtotal impuesto total].each do |c|
        next if vieja[c] == nueva[c]

        diferencias << "nota #{n} (#{moneda}) #{c}: vieja #{vieja[c].to_s('F')} gema #{nueva[c].to_s('F')}"
      end
    end

    assert_operator lineas_probadas, :>, 10_000
    assert_empty diferencias, "DIFERENCIAS DE PLATA (no ajustar: decide el dueño):\n#{diferencias.first(20).join("\n")}"
  end
end
