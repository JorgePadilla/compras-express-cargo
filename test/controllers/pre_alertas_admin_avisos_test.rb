require "test_helper"

# PR-C6.47: admin ve los mismos candados que el cliente, pero puede pasar por
# encima.
#
# El portal bloquea dos cosas: editar una consolidación finalizada, y tocar el
# tracking de un paquete que ya llegó a bodega. Admin no tenía ni el bloqueo ni
# el aviso — o sea, podía romper las dos sin enterarse.
#
# La decisión de Jorge fue **avisar, no bloquear**, y la razón está en lo que
# Yusef ya había dicho de mover paquetes: *"se permite mover a pre-alerta de
# cualquier cliente (caso típico: corregir asignación equivocada)"*. Corregir
# errores es el trabajo del equipo; si esta pantalla tampoco dejara, no habría
# dónde hacerlo.
#
# Por eso los asserts de "sigue editable" son tan importantes como los del
# aviso: son la decisión escrita en código.
class PreAlertasAdminAvisosTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @pa = pre_alertas(:activa)
  end

  # ── Consolidación finalizada ──

  test "avisa que la consolidacion ya se cerro" do
    @pa.update_columns(consolidado: true, finalizado: true)

    get edit_pre_alerta_url(@pa)

    assert_select "[data-banner=finalizada]"
  end

  test "una pre-alerta viva no muestra el aviso" do
    @pa.update_columns(finalizado: false)

    get edit_pre_alerta_url(@pa)

    assert_select "[data-banner=finalizada]", count: 0
  end

  test "aunque este finalizada los campos siguen editables" do
    # ESTE es el test de la decisión. Si alguien agrega `disabled:` o
    # `readonly:` "por seguridad", acá se entera.
    @pa.update_columns(consolidado: true, finalizado: true)

    get edit_pre_alerta_url(@pa)

    campo = response.body[/<input[^>]*\[0\]\[tracking\][^>]*>/].to_s
    assert campo.present?, "no encontré el campo de tracking"
    assert_no_match(/\bdisabled\b/, campo)
    assert_no_match(/\breadonly\b/, campo)
  end

  test "guardar una finalizada funciona" do
    # El portal corta acá (`Cuenta::PreAlertasController#update` hace `return`
    # si `finalizado?`). Admin no, y es a propósito.
    @pa.update_columns(consolidado: true, finalizado: true)

    patch pre_alerta_url(@pa), params: { pre_alerta: { titulo: "Corregido despues de cerrar" } }

    assert_redirected_to pre_alerta_url(@pa)
    assert_equal "Corregido despues de cerrar", @pa.reload.titulo
  end

  # ── Paquete que ya llegó ──

  test "avisa cuando el paquete ya se recibio" do
    pap = con_paquete_recibido

    get edit_pre_alerta_url(@pa)

    assert_select "#paquete_row_#{pap.id} [data-aviso=ya-recibido]"
  end

  test "un paquete que todavia no llega no muestra el aviso" do
    pap = @pa.pre_alerta_paquetes.create!(tracking: "1Z999AVISO2", descripcion: "Zapatos")

    get edit_pre_alerta_url(@pa)

    assert_select "#paquete_row_#{pap.id} [data-aviso=ya-recibido]", count: 0
  end

  test "el tracking de un paquete ya recibido sigue editable" do
    # El portal lo pasa a `hidden_field` y muestra el texto. Acá no: es la única
    # forma de arreglar un tracking mal tecleado cuando la caja ya llegó.
    pap = con_paquete_recibido

    get edit_pre_alerta_url(@pa)

    fila = response.body[/<tr[^>]*id="paquete_row_#{pap.id}".*?<\/tr>/m].to_s
    campo = fila[/<input[^>]*\[tracking\][^>]*>/].to_s
    assert_match(/type="text"/, campo, "lo convirtieron en hidden, como el portal")
    assert_no_match(/\bdisabled\b/, campo)
  end

  # ── El sanitizador ──

  test "el campo de tracking limpia lo que no corresponde" do
    get edit_pre_alerta_url(@pa)

    campo = response.body[/<input[^>]*\[0\]\[tracking\][^>]*>/].to_s
    assert_match(/tracking-input#sanitize/, campo)
    assert_match(/data-tracking-input-target="input"/, campo)
  end

  test "el sanitizador corre antes de preguntar por el duplicado" do
    # Si preguntara primero, la consulta saldría con el espacio de más.
    get edit_pre_alerta_url(@pa)

    accion = response.body[/<input[^>]*\[0\]\[tracking\][^>]*>/][/data-action="([^"]*)"/, 1].to_s
    assert_operator accion.index("tracking-input#sanitize"), :<,
                    accion.index("tracking-duplicado#buscar")
  end

  test "el sanitizador tiene donde avisar lo que saco" do
    # Sin el target, `_showError` corta en seco y el carácter desaparece en
    # silencio — que es bloquear, no avisar.
    get edit_pre_alerta_url(@pa)

    assert_select "[data-tracking-input-target=error]"
  end

  test "new tambien limpia el tracking" do
    get new_pre_alerta_url

    campo = response.body[/<input[^>]*\[0\]\[tracking\][^>]*>/].to_s
    assert_match(/tracking-input#sanitize/, campo)
  end

  private

  def con_paquete_recibido
    pap = @pa.pre_alerta_paquetes.create!(tracking: "1Z999AVISO1", descripcion: "Zapatos")
    pap.reload.paquete.update_columns(estado: "recibido_miami")
    pap.reload
  end
end
