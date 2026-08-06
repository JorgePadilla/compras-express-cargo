require "test_helper"

# PR-13.b: que el descuento se vea. El punto de volverlo un campo propio era
# justamente que dejara de ser invisible — si se guarda pero no se imprime, se
# vuelve a lo de antes con más pasos.
class DescuentoVisibleTest < ActionDispatch::IntegrationTest
  setup do
    TarifasPropuesta2026.sembrar!
    post session_url, params: { email_address: users(:cajero).email_address,
                                password: "password123" }
    @cliente = clientes(:juan)
  end

  test "la pre-factura muestra el descuento y el importe gravado" do
    pf = pre_factura_con_descuento

    get pre_factura_url(pf)

    assert_response :success
    assert_match "Descuento", response.body
    assert_match "Importe gravado", response.body
    # 1,118.30 − 111.83 = 1,006.47
    assert_match "1,006.47", response.body
  end

  test "la pantalla de edicion muestra el descuento por linea" do
    pf = pre_factura_con_descuento

    get edit_pre_factura_url(pf)

    assert_response :success
    assert_match "111.83", response.body
    assert_match "Cliente frecuente", response.body
  end

  test "la factura del cliente muestra el descuento en su portal" do
    pf = pre_factura_con_descuento
    venta = pf.facturar!

    delete session_url
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }

    get cuenta_factura_url(venta)

    assert_response :success
    assert_match "Descuento", response.body
    assert_match "Importe gravado", response.body
  end

  # El riesgo real del PDF no es el texto sino que Prawn reviente: la tabla de
  # items pasa de 4 a 5 columnas cuando hay descuento, y un ancho mal repartido
  # tira `Prawn::Errors::CannotFit`.
  test "el PDF de la factura se genera con y sin descuento" do
    sin_descuento = VentaPdf.new(ventas(:pendiente_juan)).render
    assert sin_descuento.start_with?("%PDF-")

    venta = pre_factura_con_descuento.facturar!
    con_descuento = VentaPdf.new(venta).render

    assert con_descuento.start_with?("%PDF-")
    assert_operator con_descuento.bytesize, :>, 0
  end

  private

  def pre_factura_con_descuento
    paquete = Paquete.create!(
      tracking: "DESCVIS#{SecureRandom.hex(3)}",
      cliente: @cliente,
      tipo_envio: tipo_envios(:cer),
      sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega",
      peso: 10, peso_cobrar: 10,
      cantidad_productos: 1, cantidad_paquetes: 1,
      descripcion: "Paquete de prueba",
      user: users(:digitador)
    )
    pf = PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: users(:cajero))
    pf.save!
    item = pf.pre_factura_items.first
    item.aplicar_descuento_porcentaje(10)
    item.descuento_motivo = "Cliente frecuente"
    pf.save!
    pf
  end
end
