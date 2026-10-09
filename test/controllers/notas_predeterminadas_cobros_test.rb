require "test_helper"

# PR-C6.13: las notas predeterminadas también en pre-factura y caja, y visibles
# desde el paquete.
#
# Yusef, 2026-08-08:
#
#   "Esto que vos tenés, este modal, lo vas a usar también en facturación, en
#    prefactura. Siempre se usan estos predeterminados."
#
# Para qué: "siempre tenemos, digamos, no se le dio tarifa... **no cumple el
# mínimo** y se le cobró tarifa tal". Un clic en vez de escribir lo mismo cada
# vez.
#
# Y la segunda mitad, que es la que importa para servicio al cliente:
#
#   "Esa información me tiene que aparecer si yo entro aquí."
class NotasPredeterminadasCobrosTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @plantilla = PlantillaNotaCliente.create!(
      titulo: "No cumple mínimo",
      texto: "Debido a que no cumple el mínimo se le está cobrando una tarifa de...",
      activo: true
    )
  end

  test "la pre-factura ofrece las notas frecuentes" do
    # El bloque de notas vive en el paso 2 del flujo: recién aparece con un
    # cliente elegido Y paquetes facturables. Sin eso la página es el buscador.
    get new_pre_factura_url, params: { cliente_id: cliente_con_paquete_facturable.id }

    assert_response :success
    assert_match(/Notas frecuentes/, response.body)
    assert_match @plantilla.titulo, response.body
  end

  test "editar una pre-factura tambien las ofrece" do
    get edit_pre_factura_url(pre_facturas(:borrador_juan))

    assert_response :success
    assert_match(/Notas frecuentes/, response.body)
  end

  test "caja tambien las ofrece" do
    # El form de apertura aparece cuando NO hay apertura del día
    # (`AperturaCaja.del_dia` en nil), que es cuando se escriben las notas.
    AperturaCaja.where(fecha: Date.current).destroy_all
    get caja_url

    assert_response :success
    assert_match(/Notas frecuentes/, response.body)
  end

  test "el picker apunta al campo de notas correcto" do
    # Si el selector no matchea, los botones no hacen nada y nadie se entera.
    get new_pre_factura_url, params: { cliente_id: cliente_con_paquete_facturable.id }

    assert_match(/data-plantilla-picker-target-selector-value="#pre_factura_notas"/, response.body)
    assert_match(/id="pre_factura_notas"/, response.body)
  end

  test "sin plantillas cargadas no se muestra nada" do
    PlantillaNotaCliente.update_all(activo: false)

    get new_pre_factura_url, params: { cliente_id: cliente_con_paquete_facturable.id }

    assert_no_match(/Notas frecuentes/, response.body)
  end

  # ── La segunda mitad: verlas desde el paquete ──────────────────────────

  def cliente_con_paquete_facturable
    cliente = clientes(:juan)
    Paquete.create!(
      tracking: "FACT#{SecureRandom.hex(4)}", cliente: cliente,
      tipo_envio: tipo_envios(:cer), sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega", peso: 5, peso_cobrar: 5,
      cantidad_productos: 1, cantidad_paquetes: 1, descripcion: "x",
      user: users(:digitador)
    )
    cliente
  end

  test "las notas de la pre-factura se ven en el detalle del paquete" do
    pf = pre_facturas(:borrador_juan)
    pf.update!(notas: "No cumple el mínimo, se cobró tarifa mínima.")
    paquete = paquetes(:recibido)
    paquete.update!(pre_factura: pf)

    get paquete_url(paquete)

    assert_match "No cumple el mínimo", response.body
    assert_match(/Notas de facturación/, response.body)
  end

  test "un paquete sin documentos de cobro no muestra la seccion" do
    get paquete_url(paquetes(:recibido))

    assert_no_match(/Notas de facturación/, response.body)
  end
end
