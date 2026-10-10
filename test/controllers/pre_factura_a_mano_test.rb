require "test_helper"

# PR-P.10 · /pre_facturas/new es la puerta de las excepciones, y cobra por
# volumen cuando el paquete tiene uno.
#
# Jorge, 2026-10-10: *"the old prefactura now doesn't make a lot of sense"*.
# Lo que cuidan estos tests: F1 del índice va a preparar (lo normal); el paso 2
# muestra una tanda medida como UNA fila con UN check; `create` cobra la tanda
# entera por volumen aunque se mande una sola caja; y el total que la pantalla
# muestra es el que se guarda.
class PreFacturaAManoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:cajero)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cliente = clientes(:juan)
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
  end

  def caja(peso: 2, **extra)
    Paquete.create!(tracking: "1ZMANO#{SecureRandom.hex(5).upcase}", cliente: @cliente,
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", peso: peso, **extra)
  end

  def medir(cajas, *volumenes)
    MedirBulto.new(user: users(:supervisor_prefactura)).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  # PR-P.11a · Medición ya no deja medir juntas prepagadas y no prepagadas: la
  # tanda mezclada de estos tests es una medida antes, marcada después.
  def prepagar(paquete) = paquete.update_columns(prepagado_miami: true, prepagado_miami_metodo: "efectivo")

  def lps(monto) = ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", monto))

  # ── El índice ───────────────────────────────────────────────────────────

  test "F1 del índice va a Preparar pre-factura, y la de a mano queda sin tecla" do
    get pre_facturas_url

    assert_select "a[href=?][data-shortcut=F1]", hoja_de_preparacion_path, text: /Preparar pre-factura/
    assert_select "a[href=?]", new_pre_factura_path, text: /A mano \(excepciones\)/
    assert_select "a[href=?][data-shortcut]", new_pre_factura_path, false
  end

  test "la pantalla de a mano dice para qué es, y manda a preparar" do
    get new_pre_factura_url

    assert_select "[data-aviso=excepciones]", text: /prepagado en Miami/
    assert_select "[data-aviso=excepciones] a[href=?]", hoja_de_preparacion_path, text: "Lo normal es Preparar pre-factura"
  end

  # ── El paso 2 ───────────────────────────────────────────────────────────

  test "el paso 2 muestra la tanda como UNA fila con UN check, y lo demás por paquete" do
    cajas = [ caja, caja ]
    bulto_uno, = medir(cajas, { peso: "6" }, { peso: "12.5" })
    rechazadas = [ caja(peso: 5), caja ]
    rechazada, = medir(rechazadas, { peso: "9" })
    prepagar(rechazadas.last)
    suelta = caja(peso: 3)

    get new_pre_factura_url, params: { cliente_id: @cliente.id }
    assert_response :success

    assert_select "input[name='paquete_ids[]'][value=?]", cajas.map(&:id).join(","), count: 1
    cajas.each { |c| assert_select "input#paquete_#{c.id}", false }
    assert_select "tr[data-tanda=?]", bulto_uno.sesion do
      assert_select "li", text: /Volumen 1 de 2 · 6 lb/
      assert_select "li", text: /Volumen 2 de 2 · 12\.5 lb/
    end

    assert_select "tr[data-tanda-rechazada=?]", rechazada.sesion, text: /prepagada en Miami/
    rechazadas.each { |c| assert_select "input#paquete_#{c.id}" }
    assert_select "input#paquete_#{suelta.id}"
  end

  test "el precio de la fila de la tanda es el que guarda la pre-factura" do
    cajas = [ caja, caja ]
    bulto, = medir(cajas, { peso: "12" })

    get new_pre_factura_url, params: { cliente_id: @cliente.id }
    mostrado = css_select("tr[data-tanda] [data-subtotal-tanda]").first.text.strip
    post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ cajas.map(&:id).join(",") ] }

    linea = PreFactura.last.pre_factura_items.find { |i| i.origen == "volumen" }
    assert_equal bulto, linea.bulto
    assert_equal "L. #{lps(linea.subtotal)}", mostrado
    get new_pre_factura_url, params: { cliente_id: @cliente.id } # ya no está: la tanda quedó tomada
    assert_select "tr[data-tanda]", false
  end

  # ── create ──────────────────────────────────────────────────────────────

  test "crear con UNA caja de la tanda guarda la tanda entera, por volumen" do
    cajas = [ caja(peso: 2), caja(peso: 2) ]
    bulto, = medir(cajas, { peso: "12" })
    esperado = ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: [ bulto.sesion ]).pre_factura_items
                                        .sum { |i| i.subtotal.to_d }

    assert_difference "PreFactura.count", 1 do
      post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ cajas.first.id ] }
    end

    pf = PreFactura.last
    assert_redirected_to edit_pre_factura_path(pf)
    assert_equal cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    assert_equal [ "caja_del_volumen", "caja_del_volumen", "volumen" ], pf.pre_factura_items.map(&:origen).sort
    assert_equal esperado, pf.subtotal
    assert_equal (BigDecimal("12") * CurrencyAware.convertir(4.50, de: "USD", a: "LPS")).round(2), pf.subtotal,
                 "12 lb del volumen, no 2 + 2 de Miami"
    assert_equal [ users(:cajero), "creado" ], [ pf.creado_por, pf.estado ]
  end

  test "una tanda rechazada se cobra por paquete y el flash dice por qué" do
    normal = caja(peso: 5)
    prepagada = caja
    medir([ normal, prepagada ], { peso: "8" })
    prepagar(prepagada)

    post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: [ normal.id, prepagada.id ] }

    pf = PreFactura.last
    assert_equal %w[manual manual], pf.pre_factura_items.map(&:origen)
    assert_match(/prepagado\(s\) en Miami/, flash[:notice])
    assert_match(/1 tanda\(s\) medida\(s\) se cobraron por paquete.*prepagada en Miami/, flash[:notice])
  end

  # ── El total de la pantalla es el que se guarda ─────────────────────────

  test "el total que muestra la pantalla es el total guardado, con tanda, rechazo, suelto y cargos automáticos" do
    medidas = [ caja(peso: 2), caja(peso: 2, recolecta_solicitada: true, recolecta_monto: 35.0, recolecta_moneda: "USD") ]
    medir(medidas, { peso: "12.3" })
    rechazadas = [ caja(peso: 6), caja ]
    medir(rechazadas, { peso: "9" })
    prepagar(rechazadas.last)
    suelta = caja(peso: 0.5)
    marcados = [ medidas.map(&:id).join(","), *rechazadas.map(&:id), suelta.id ]

    get cotizacion_pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: marcados }
    assert_response :success
    assert_select "turbo-frame#cotizacion_pre_factura"
    mostrado = css_select("[data-monto=total]").first.text.strip

    post pre_facturas_url, params: { cliente_id: @cliente.id, paquete_ids: marcados }
    pf = PreFactura.last

    assert_equal 5, pf.paquetes.count
    assert pf.pre_factura_items.any? { |i| i.origen == "auto_recolecta" }
    assert_equal "L. #{lps(pf.total)}", mostrado
  end

  test "sin nada marcado el total lo dice, y no arma nada" do
    get cotizacion_pre_facturas_url, params: { cliente_id: @cliente.id }

    assert_response :success
    assert_select "#total_pre_factura", text: /Marcá paquetes/
  end
end
