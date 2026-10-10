require "test_helper"

# C30-19 · PR-P.3 · La etiqueta de entrega 4×6, desde la ficha de la
# pre-factura. Lo que la etiqueta pesa y cómo cabe lo miden
# `test/models/etiqueta_de_entrega_test.rb` y `etiqueta_entrega_cabe_test`.
class PreFacturaEtiquetaEntregaTest < ActionDispatch::IntegrationTest
  include EtiquetaHelper

  setup do
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }
    @pf = pre_facturas(:borrador_juan)
  end

  test "la ficha trae «Imprimir etiqueta» con F4, en pestaña nueva y que imprime sola" do
    get pre_factura_path(@pf)

    href = etiqueta_entrega_pre_factura_path(@pf, print: true)
    assert_select "a[href='#{href}'][target='_blank'][data-shortcut='F4']", text: /Imprimir etiqueta/
  end

  test "la etiqueta lleva el QR de la entrega y los datos de Yusef" do
    get etiqueta_entrega_pre_factura_path(@pf)

    assert_response :success
    assert_includes response.body, etiqueta_qr_svg("ENT PF-000001", tamano: "1.5in"),
                    "el QR tiene que decir «ENT <número>»"
    assert_select ".nombre", text: "Juan Perez"
    assert_select ".cliente-codigo", text: "CEC-001"
    assert_select ".pf", text: "PF-000001"
    assert_select ".cifra", text: /LBS A COBRAR\s*10\.00/
    assert_select ".fecha", text: Date.current.strftime("%d/%m/%Y")
  end

  # La columna `consolidando_at` llega con PR-P.2; hasta entonces no hay franja.
  test "sin consolidar no sale la franja" do
    get etiqueta_entrega_pre_factura_path(@pf)

    assert_select ".franja", count: 0
    assert_not_includes response.body, "CONSOLIDANDO"
  end

  test "quien no es de pre-factura no la ve" do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }

    get etiqueta_entrega_pre_factura_path(@pf)

    assert_redirected_to root_path
  end
end
