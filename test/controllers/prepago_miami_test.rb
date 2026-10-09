require "test_helper"

# PR: el sellado del prepago, desde las DOS pantallas de Miami.
#
# El flag viene del form como un booleano y se traduce a cinco columnas. Se
# prueba que las dos pantallas lo sellen igual — porque hasta ahora solo una lo
# hacía, y la otra ni siquiera ofrecía el marcado.
#
# Va como test de integración y no de sistema **a propósito**: CI corre
# `rails test`, que no incluye `test/system`. Un system test acá no cuidaría
# nada en CI — es la lección que dejó `PR-C7.17`.
class PrepagoMiamiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  # ── /entrega_personal, que ya lo tenía ──────────────────────────────────

  test "entrega personal sella las cinco columnas" do
    assert_difference "Paquete.count", 1 do
      post entrega_personal_index_url,
           params: { paquete: ep_attrs.merge(prepagado_miami: "1", prepagado_miami_metodo: "zelle") }
    end

    p = Paquete.order(:id).last
    assert p.prepagado_miami?
    assert_equal "zelle", p.prepagado_miami_metodo
    assert_equal @user, p.prepagado_miami_by_user
    assert p.prepagado_miami_at.present?
  end

  test "sin prepago no queda rastro" do
    post entrega_personal_index_url, params: { paquete: ep_attrs.merge(prepagado_miami: "0") }

    p = Paquete.order(:id).last
    assert_not p.prepagado_miami?
    assert_nil p.prepagado_miami_metodo
    assert_nil p.prepagado_miami_at
    assert_nil p.prepagado_miami_by_user_id
  end

  test "un metodo sin prepago no se cuela" do
    # El del que se arrepintió: el radio vuelve a "cobrar en Honduras" pero el
    # método sigue viajando en el request. No puede quedar guardado, o el
    # Warehouse Receipt diría que se pagó algo que no se pagó.
    post entrega_personal_index_url,
         params: { paquete: ep_attrs.merge(prepagado_miami: "0", prepagado_miami_metodo: "zelle") }

    p = Paquete.order(:id).last
    assert_not p.prepagado_miami?
    assert_nil p.prepagado_miami_metodo
  end

  # ── /etiquetar, que es la mitad nueva ───────────────────────────────────

  test "etiquetar tambien sella el prepago" do
    # Esta pantalla NO tenía el marcado: existía solo en entrega personal.
    # Yusef: "esto es en la parte de Miami — etiquetar y entrega personal".
    iniciar_etiquetado

    assert_difference "Paquete.count", 1 do
      post etiquetar_url,
           params: { paquete: etiquetar_attrs.merge(prepagado_miami: "1", prepagado_miami_metodo: "tarjeta") }
    end

    p = Paquete.order(:id).last
    assert p.prepagado_miami?
    assert_equal "tarjeta", p.prepagado_miami_metodo
    assert_equal @user, p.prepagado_miami_by_user
    assert p.prepagado_miami_at.present?
  end

  test "en un split las tres cajas quedan pagadas" do
    # El pago es del envío, no de la caja: el cliente pagó el tracking.
    iniciar_etiquetado

    assert_difference "Paquete.count", 3 do
      post etiquetar_url, params: { paquete: etiquetar_attrs.merge(
        prepagado_miami: "1", prepagado_miami_metodo: "efectivo",
        cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 2 } }
      ) }
    end

    tres = Paquete.order(:id).last(3)
    assert(tres.all?(&:prepagado_miami?), "alguna caja quedó sin marcar")
    assert_equal [ "efectivo" ], tres.map(&:prepagado_miami_metodo).uniq
  end

  test "desmarcar el prepago al editar borra el rastro entero" do
    # La rama que faltaba en el código viejo: `apply_extra_params` solo actuaba
    # cuando el flag venía en true, así que arrepentirse dejaba puestos la
    # fecha, el usuario y la sucursal de un cobro que ya no existe.
    iniciar_etiquetado
    post etiquetar_url,
         params: { paquete: etiquetar_attrs.merge(prepagado_miami: "1", prepagado_miami_metodo: "zelle") }
    p = Paquete.order(:id).last
    assert p.prepagado_miami?

    patch actualizar_etiquetar_url(p), params: { paquete: { prepagado_miami: "0" } }

    p.reload
    assert_not p.prepagado_miami?
    assert_nil p.prepagado_miami_metodo
    assert_nil p.prepagado_miami_at
    assert_nil p.prepagado_miami_by_user_id
    assert_nil p.prepagado_miami_sucursal_id
  end

  test "la pantalla de etiquetar ofrece el marcado" do
    iniciar_etiquetado
    get etiquetar_url

    assert_response :success
    assert_match(/Pagado aquí en Miami/, response.body)
    assert_match(/¿Cómo se recibió el pago\?/, response.body)
  end

  private

  def iniciar_etiquetado
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id,
                   sucursal_recepcion_id: sucursales(:miami).id }
  end

  def ep_attrs
    {
      cliente_id: @cliente.id,
      tipo_envio_id: tipo_envios(:cer).id,
      sucursal_recepcion_id: sucursales(:miami).id,
      proveedor_id: proveedores(:driver_entrega).id,
      descripcion: "Caja de prueba",
      peso: 5
    }
  end

  def etiquetar_attrs
    {
      cliente_id: @cliente.id,
      tracking: "1Z#{SecureRandom.hex(5).upcase}",
      descripcion: "Caja de prueba",
      peso: 5
    }
  end
end
