require "test_helper"

# C20-06: al dar de alta un tracking dividido sale UNA ventana de impresión,
# no una por caja.
#
# Cada evento con `data-print` abre su propia pestaña, y cada pestaña imprime
# TODAS las hermanas (`?hermanas=1`): dos cajas eran cuatro etiquetas, tres
# eran nueve. No se veía porque Chrome deja pasar un solo popup por gesto del
# usuario —el mismo límite que ya nos mordió en `PR-C7.28`—, así que el bug
# estaba tapado por el navegador. El día que alguien le dé permiso al sitio en
# la estación de Miami, empieza a salir papel de más.
class EtiquetarUnaSolaImpresionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  test "un alta dividida en 3 pide UNA impresión, no tres" do
    guardar_split(3)

    assert_response :success
    assert_equal 3, response.body.scan(/data-action='paquete-saved'/).size,
                 "cada caja conserva su evento: el sonido y la limpieza son por caja"
    assert_equal 1, response.body.scan(/data-print='true'/).size,
                 "N pestañas × N etiquetas: tres cajas imprimían nueve"
  end

  test "la que imprime es la primera caja, que trae a las hermanas" do
    guardar_split(2)

    cajas = Paquete.where(tracking: @tracking).order(:numero_caja)
    assert_match(/data-print='true' data-paquete-id='#{cajas.first.id}'/, response.body)

    # Y desde ella salen las dos, que es lo que Yusef quiere ver.
    get etiqueta_paquete_url(cajas.first, hermanas: 1)
    assert_equal 2, response.body.scan(/class="etq"/).size
  end

  test "sin imprimir no se marca ninguna" do
    guardar_split(2, print: nil)

    assert_equal 0, response.body.scan(/data-print='true'/).size
  end

  private

  def guardar_split(n, print: "true")
    @tracking = "IMP#{SecureRandom.hex(4)}"
    post etiquetar_url,
         params: {
           etiquetas: n, print: print,
           paquete: { tracking: @tracking, cliente_id: clientes(:juan).id,
                      descripcion: "Perfumes" }
         }.compact,
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end
end
