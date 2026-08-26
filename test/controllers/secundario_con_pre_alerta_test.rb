require "test_helper"

# Un bulto llega con **dos** trackings —el del carrier y el del comercio— y el
# cliente pre-alerta uno, o el otro, o los dos.
#
# Yusef, 2026-08-18, escaneando el segundo y viendo salir el modal de duplicado:
#
#   > *"Esto, según tus reglas del inicio, no debería pasar… aquí está agarrando
#   >  la regla de que existe el tracking y no la regla de que es una
#   >  pre-alerta."*
#
# Y la otra mitad, la del guardado:
#
#   > *"Tiene que jalar esta información, compararlo, venir y unificarlos acá y
#   >  eliminarlo de la pre-alerta. **No es vincularlo, eliminarlo**."*
#
# Sin eso, el esperado del secundario quedaba huérfano igual que el fantasma de
# `PR-C7.20`, solo que por la otra puerta: la reconciliación miraba **un** solo
# tracking.
class SecundarioConPreAlertaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id
    }
  end

  # ── Lo que ve el operario al escanear ───────────────────────────────────

  test "el JSON dice que el secundario tiene pre-alerta, no que es un duplicado" do
    pre_alertar("1ZSECUNDARIO00001")

    get check_tracking_paquetes_url(tracking: "1ZSECUNDARIO00001"), as: :json
    json = JSON.parse(response.body)

    assert json["pre_alerta_match"], "no lo reconoció como pre-alerta"
    assert json.key?("cliente_id"), "sin el cliente no se puede comparar"
    assert json.key?("pre_alerta_tipo_envio_id"), "sin el tipo de envío no se puede comparar"
  end

  test "la pantalla revisa el secundario antes de tratarlo como duplicado" do
    # Es la causa exacta de lo que reportó: `checkTracking` tiene la rama de
    # pre-alerta desde `PR-2` y en el secundario se copió solo el duplicado.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    metodo = src[/checkTrackingSecundario\(\)\s*\{.*?\n  \}/m]
    assert metodo, "no se encontró checkTrackingSecundario"

    assert_includes metodo, "pre_alerta_match"
    assert_match(/pre_alerta_match.*return/m, metodo,
                 "el secundario con pre-alerta sigue cayendo al modal de duplicado")
  end

  test "y compara el cliente y el tipo de envio antes de dejarlo pasar" do
    # Las dos incongruencias que dictó: *"hay una diferencia en el tipo de
    # envío"* y *"está a nombre de dos personas diferentes"*. La del tipo de
    # envío se reusa de `_avisarConflictoDeSesion`, que ya la hace para el
    # primario — escribirla de nuevo sería la separación de siempre.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    revision = src[/_revisarSecundarioConPreAlerta\(data\)\s*\{.*?\n  \}/m]
    assert revision, "no se encontró la revisión del secundario"

    assert_includes revision, "clienteIdTarget", "no compara contra el cliente del formulario"
    assert_includes revision, "_avisarConflictoDeSesion", "no reusa la comparación del tipo de envío"
  end

  # ── Lo que pasa al guardar ──────────────────────────────────────────────

  test "el esperado del secundario no queda huerfano" do
    principal = pre_alertar("1ZPRINCIPAL00001")
    secundario = pre_alertar("1ZSEGUNDO0000001")

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: secundario.tracking,
      cliente_id: clientes(:juan).id, descripcion: "Un bulto, dos códigos", peso: 10
    } }

    paquete = Paquete.find_by(tracking: principal.tracking)
    assert paquete, "no se guardó el paquete"
    assert_nil Paquete.find_by(id: secundario.paquete_id),
               "el esperado del secundario quedó de fantasma"
    assert_equal paquete.id, secundario.reload.paquete_id,
                 "la pre-alerta del secundario no se reapuntó"
  end

  test "el JSON del secundario absorbido trae el cliente de SU pre-alerta, no el del otro renglon" do
    # C16-05: después de guardar, el paquete tiene dos renglones vinculados —el
    # del primario y el del secundario absorbido—. `find_by(paquete_id:)` sin
    # orden devolvía cualquiera, y la pantalla comparaba contra el cliente
    # equivocado: el aviso de «está a nombre de otro» se callaba al azar.
    principal = pre_alertar("1ZPRINCIPAL00009")
    secundario = pre_alertar("1ZSEGUNDO0000009", cliente: clientes(:maria))

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: secundario.tracking,
      cliente_id: clientes(:juan).id, descripcion: "x", peso: 10
    } }
    paquete = Paquete.find_by(tracking: principal.tracking)
    assert_equal 2, PreAlertaPaquete.where(paquete_id: paquete.id).count, "el secundario no se absorbió"

    get check_tracking_paquetes_url(tracking: secundario.tracking), as: :json
    assert_equal clientes(:maria).id, JSON.parse(response.body)["cliente_id"]

    get check_tracking_paquetes_url(tracking: principal.tracking), as: :json
    assert_equal clientes(:juan).id, JSON.parse(response.body)["cliente_id"]
  end

  test "las dos pre-alertas quedan al dia" do
    principal = pre_alertar("1ZPRINCIPAL00002")
    secundario = pre_alertar("1ZSEGUNDO0000002")

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: secundario.tracking,
      cliente_id: clientes(:juan).id, descripcion: "x", peso: 10
    } }

    assert_equal "recibido", principal.pre_alerta.reload.estado
    assert_equal "recibido", secundario.pre_alerta.reload.estado
  end

  test "tambien cuando el bulto se divide en cajas" do
    # `create_split` es el otro camino, y ya se separó una vez.
    principal = pre_alertar("1ZPRINCIPAL00003")
    secundario = pre_alertar("1ZSEGUNDO0000003")

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: secundario.tracking,
      cliente_id: clientes(:juan).id, descripcion: "x",
      cajas: { "1" => { peso: 12.5 }, "2" => { peso: 30 } }
    } }

    cajas = Paquete.where(tracking: principal.tracking)
    assert_equal 2, cajas.size, "quedó un fantasma al lado de las cajas"
    assert_nil Paquete.find_by(id: secundario.paquete_id)
  end

  test "sin secundario no se toca nada" do
    principal = pre_alertar("1ZPRINCIPAL00004")

    assert_nothing_raised do
      post etiquetar_url, params: { paquete: {
        tracking: principal.tracking, cliente_id: clientes(:juan).id,
        descripcion: "x", peso: 10
      } }
    end

    assert_equal "recibido_miami", Paquete.find_by(tracking: principal.tracking).estado
  end

  test "un secundario sin pre-alerta tampoco rompe nada" do
    principal = pre_alertar("1ZPRINCIPAL00005")

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: "1ZSINPREALERTA01",
      cliente_id: clientes(:juan).id, descripcion: "x", peso: 10
    } }

    paquete = Paquete.find_by(tracking: principal.tracking)
    assert_equal "1ZSINPREALERTA01", paquete.tracking_secundario
  end

  test "un esperado que ya entro a una pre-factura no se borra" do
    # Mismo criterio que la limpieza masiva: lo que ya está en un documento no
    # desaparece en silencio.
    principal = pre_alertar("1ZPRINCIPAL00006")
    secundario = pre_alertar("1ZSEGUNDO0000006")
    PreFacturaItem.create!(pre_factura: pre_facturas(:borrador_juan),
                           paquete_id: secundario.paquete_id, concepto: "Flete", subtotal: 10)

    post etiquetar_url, params: { paquete: {
      tracking: principal.tracking, tracking_secundario: secundario.tracking,
      cliente_id: clientes(:juan).id, descripcion: "x", peso: 10
    } }

    assert Paquete.exists?(secundario.paquete_id)
  end

  private

  def pre_alertar(tracking, cliente: clientes(:juan))
    pa = PreAlerta.create!(cliente: cliente, tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciado", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Lo que viene")
  end
end
