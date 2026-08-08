require "test_helper"

# PR-C6.11: el orden de campos que Yusef dictó recorriendo la pantalla.
#
# Se prueba por **posición en el HTML** siguiendo el patrón que ya usa
# `etiquetar_ux_test.rb`: comparar `body.index(...)`. Es lo único que puede
# fijar un orden sin depender de clases de Tailwind, que cambian seguido.
class EtiquetarOrdenCamposTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
    get etiquetar_url
    @body = response.body
  end

  test "notas internas va arriba del cuadro de carrier y proveedor" do
    # Yusef: "notas internas, aquí es donde creo yo que esto lo deberíamos de
    # poner acá arriba, arriba de esto".
    assert_operator pos("Notas Internas"), :<, pos(">Carrier<"),
                    "las notas internas quedaron debajo del carrier"
  end

  test "carrier, proveedor y remitente van juntos al final" do
    # Yusef: "move carrier, proveedor y remitente en este cuadro que está acá
    # abajo, porque es parte de lo que van a llenar".
    carrier = pos(">Carrier<")
    assert_operator carrier, :<, pos("paquete_proveedor")
    assert_operator pos("paquete_proveedor"), :<, pos("paquete_remitente")
  end

  test "se fueron los checkboxes de Pre-Alerta y Pre-Factura" do
    # Yusef: "esto de prealerta, prefactura... esto no, esto no tiene nada que
    # ver con ellos". Jorge confirmó que habían quedado del inicio.
    assert_no_match(/id="paquete_pre_alerta"/, @body)
    assert_no_match(/id="paquete_pre_factura"/, @body)
  end

  test "los atajos estan arriba Y abajo" do
    # Yusef: "estos botones los dejaste abajo y a veces se ocupan acá arriba.
    # En ambos lados".
    # Se cuentan las BARRAS por su marca, no los textos ni las acciones:
    # "Guardar + Imprimir" sale dos veces por barra (leyenda + botón), y
    # `clearForm` lo usa además el banner de conflicto de sesión (PR-C6.9).
    # Contar cualquiera de esas cosas mide otra cosa.
    assert_equal 2, @body.scan(/data-barra="atajos"/).size,
                 "los atajos tienen que estar en los dos extremos del form"
  end

  test "el cambio de servicio sigue estando" do
    # Se sacaron dos checkboxes, no los tres.
    assert_match(/id="paquete_solicito_cambio_servicio"/, @body)
  end

  test "en el detalle del paquete las notas van sobre proveedor" do
    # Yusef: "acá proveedor, carrier, remitente... es más importante que diga
    # notas".
    get paquete_url(paquetes(:recibido))
    cuerpo = response.body

    assert_operator cuerpo.index("Notas Internas"), :<,
                    cuerpo.index("SECCIÓN 3") || cuerpo.index(">Proveedor<"),
                    "las notas quedaron debajo de proveedor/carrier/remitente"
  end

  private

  def pos(texto)
    i = @body.index(texto)
    assert i, "no se encontró #{texto.inspect} en la página"
    i
  end
end
