require "test_helper"

# PR-C6.42 · RP-18: la pantalla desde donde el supervisor destraba un split con
# cajas de más.
#
# Va en /paquetes y no en /etiquetar porque el problema aparece **en Honduras**,
# al entregar: *"el sistema no va a querer entregar porque decía que eran dos"*.
class BajarCajasConPinControllerTest < ActionDispatch::IntegrationTest
  setup do
    @supervisor = users(:admin)
    @supervisor.update!(pin: "1234")
    post session_url, params: { email_address: @supervisor.email_address, password: "password123" }

    @cajas = crear_split(2)
    @cajas.last.update_columns(estado: "pre_facturado")
  end

  test "baja la cantidad y avisa cuantas quedaron" do
    post bajar_cajas_paquete_url(@cajas.first), params: params_validos

    assert_redirected_to paquete_url(@cajas.first)
    assert_equal 0, Paquete.where(id: @cajas.last.id).count
    assert_match(/Quedaron 1 caja/, flash[:notice])
  end

  test "si el supervisor estaba parado en la caja que se fue, no cae en un 404" do
    # Bajar de 2 a 1 desde la caja 2: el `redirect_to @paquete` obvio mandaria
    # al registro que se acaba de borrar, justo despues de una operacion que
    # salio bien.
    post bajar_cajas_paquete_url(@cajas.last), params: params_validos

    assert_redirected_to paquete_url(@cajas.first)
    follow_redirect!
    assert_response :success
  end

  test "con el PIN equivocado no borra nada y lo dice" do
    post bajar_cajas_paquete_url(@cajas.first), params: params_validos(pin: "9999")

    assert_redirected_to paquete_url(@cajas.first)
    assert_match(/PIN/, flash[:alert])
    assert_equal 2, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count
  end

  test "una caja ya facturada lo rechaza con el motivo" do
    @cajas.last.update_columns(estado: "facturado")

    post bajar_cajas_paquete_url(@cajas.first), params: params_validos

    assert_match(/nota de crédito/, flash[:alert])
    assert_equal 2, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count
  end

  # ── Los dos caminos que renderizan el show ──

  test "el show ofrece el boton cuando el paquete esta dividido" do
    get paquete_url(@cajas.first)

    assert_response :success
    assert_select "form[action=?]", bajar_cajas_paquete_path(@cajas.first)
  end

  test "el re-render de un update fallido tambien lo ofrece" do
    # Este es EL camino: se llega acá con "no se puede bajar a 1 cajas", que es
    # el momento exacto en que el operario necesita el boton. El `show` se
    # renderiza sin pasar por `#show`, asi que si los supervisores no se cargan
    # tambien acá, la pantalla revienta justo ahi.
    patch paquete_url(@cajas.first), params: { paquete: { cantidad_paquetes: 1 } }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", bajar_cajas_paquete_path(@cajas.first)
  end

  test "sin supervisores con PIN no ofrece el boton" do
    User.update_all(pin_digest: nil)

    get paquete_url(@cajas.first)

    assert_response :success
    assert_select "form[action=?]", bajar_cajas_paquete_path(@cajas.first), count: 0
    assert_select "span", text: /Ningún supervisor tiene PIN/
  end

  private

  def params_validos(pin: "1234")
    { cantidad: 1, supervisor_id: @supervisor.id, pin: pin, motivo: "eran menos cajas" }
  end

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "CTL#{SecureRandom.hex(4)}",
        cliente: clientes(:juan),
        sucursal_recepcion: sucursales(:miami),
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end
end
