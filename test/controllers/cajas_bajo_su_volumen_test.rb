require "test_helper"

# PR-P.1 · Las cajas de un volumen se ven **juntas, debajo de él**, en las
# cinco gemelas: la pre-factura (ver y editar), la factura, la factura del
# portal del cliente y el PDF.
#
# Cada caja lleva su renglón en L. 0.00 —así `confirmar!`, `facturar!` y
# `anular!` siguen encontrando sus paquetes—, pero impresos uno por uno un
# consolidado de cien cajas son cien renglones en cero. Lo que se prueba: un
# renglón con precio por volumen, y cada caja nombrada **una** vez.
class CajasBajoSuVolumenTest < ActionDispatch::IntegrationTest
  class VentaPdfQueMira < VentaPdf
    def tablas = @tablas ||= []

    def table(filas, opciones = {}, &bloque)
      tablas << filas
      super
    end
  end

  setup do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD",
                   minimo_monto: 20.00, minimo_moneda: "USD")
    @cliente = clientes(:juan)
    @cajas = 3.times.map do
      Paquete.create!(tracking: "1ZGRUPO#{SecureRandom.hex(5).upcase}", cliente: @cliente,
                      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                      estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: users(:admin)).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "3" } ])
    @pf = ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: [ @bulto.sesion ], user: users(:admin))
    @pf.save!
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
  end

  def codigos = @cajas.map { |c| c.reload.numero_recepcion_visible.presence || c.tracking }

  # En editar el concepto sale dos veces por renglón: en el campo y en el
  # botón de «Autorizar cambio».
  def assert_agrupado(body, por_renglon: 1)
    assert_equal por_renglon, body.scan("Volumen · 3 cajas").size, "un renglón por volumen"
    assert_equal 1, body.scan("3 cajas incluidas").size
    codigos.each { |codigo| assert_equal 1, body.scan(codigo).size, "#{codigo} tiene que salir una vez" }
    assert_no_match "incluida en el volumen", body, "los renglones en L. 0.00 no se pintan uno por uno"
  end

  test "la pre-factura junta las cajas debajo del volumen" do
    get pre_factura_url(@pf)

    assert_response :success
    assert_agrupado(response.body)
  end

  test "editar la pre-factura no las ofrece una por una, y guardar no las pierde" do
    get edit_pre_factura_url(@pf)

    assert_response :success
    assert_agrupado(response.body, por_renglon: 2)

    flete = @pf.pre_factura_items.find_by!(origen: "volumen")
    patch pre_factura_url(@pf), params: { pre_factura: { notas: "ok", pre_factura_items_attributes: {
      "0" => { id: flete.id, concepto: flete.concepto } } } }
    assert_equal 3, @pf.reload.pre_factura_items.where(origen: "caja_del_volumen").count
    assert_equal [ @pf.id ] * 3, @cajas.map { |c| c.reload.pre_factura_id }
  end

  test "la factura, el portal del cliente y el PDF también" do
    venta = @pf.facturar!

    get venta_url(venta)
    assert_response :success
    assert_agrupado(response.body)

    delete session_url
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
    get cuenta_factura_url(venta)
    assert_response :success
    assert_agrupado(response.body)

    # El PDF va comprimido: se miran las filas que se le pasan a la tabla.
    pdf = VentaPdfQueMira.new(venta)
    assert pdf.render.start_with?("%PDF-")
    items = pdf.tablas.first.drop(1)
    assert_equal 2, items.size, "el volumen y su renglón de cajas, no cuatro renglones"
    assert_includes items.first.first, "Volumen · 3 cajas"
    texto = items.last.first[:content]
    assert_includes texto, "3 cajas incluidas"
    codigos.each { |codigo| assert_includes texto, codigo }
  end

  test "LineasPorVolumen deja las cajas después del último volumen, y lo que no tiene volumen igual" do
    lineas = LineasPorVolumen.new(@pf.pre_factura_items.reload).to_a

    assert_equal [ "volumen" ], lineas.map { |linea, _| linea.origen }
    assert_equal @cajas.map(&:id).sort, lineas.first.last.map(&:paquete_id).sort

    # Las notas de crédito y débito no llevan volumen: pasan tal cual.
    nota = [ NotaCreditoItem.new(concepto: "uno"), NotaCreditoItem.new(concepto: "dos") ]
    assert_equal [ [ "uno", [] ], [ "dos", [] ] ], LineasPorVolumen.new(nota).map { |l, c| [ l.concepto, c ] }
  end
end
