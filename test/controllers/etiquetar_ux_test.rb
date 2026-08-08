require "test_helper"

# PR-10.c: las rutinas de UX que pidió Yusef en la reunión del 2026-08-02.
class EtiquetarUxTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
    post iniciar_sesion_etiquetar_url, params: { tipo_envio_id: tipo_envios(:express).id }
  end

  test "el tercero arranca oculto detras de F4" do
    get etiquetar_url

    assert_response :success
    assert_match "data-etiquetar-target=\"terceroContainer\"", response.body
    assert_match "Agregar tercero", response.body
    # "que sea oculto por defecto, porque confunde si no"
    assert_match(/terceroContainer[^>]*/, response.body)
    assert_match "hidden", response.body
  end

  test "remitente queda junto a carrier y proveedor" do
    get etiquetar_url

    body = response.body
    pos_carrier   = body.index("carriers-list")
    pos_proveedor = body.index("Amazon, eBay, etc.")
    pos_remitente = body.index("Nombre del remitente")

    assert pos_carrier && pos_proveedor && pos_remitente
    assert pos_remitente > pos_carrier,
           "remitente debe estar despues de carrier, en la misma fila"
    assert (pos_remitente - pos_proveedor).abs < 1500,
           "remitente y proveedor deben quedar contiguos"
  end

  test "el modal de duplicado recibe contenido y tipo de servicio" do
    paquete = paquetes(:recibido)

    get check_tracking_paquetes_url, params: { tracking: paquete.tracking }

    d = JSON.parse(response.body)
    assert d["exists"]
    # "el contenido y el tipo de servicio, esas son las dos cosas que mas te faltan"
    assert d.key?("descripcion"), "el modal necesita el contenido"
    assert d.key?("tipo_envio"), "el modal necesita el tipo de servicio"
    assert d.key?("numero_recepcion")
  end

  test "la busqueda de clientes encuentra por nombre completo y por codigo sin ceros" do
    clientes(:juan).update!(codigo: "C2", nombre: "Juan", apellido: "Perez")

    get buscar_clientes_url, params: { q: "Juan Perez" }
    codigos = JSON.parse(response.body).map { |c| c["codigo"] }
    assert_includes codigos, "C2", "antes 'Juan Perez' devolvia 0 resultados"

    # Los ceros se ignoran a ambos lados, asi que C002 tambien alcanza a
    # cualquier codigo que normalice a 2 (en las fixtures, CEC-002).
    get buscar_clientes_url, params: { q: "C002" }
    assert_includes JSON.parse(response.body).map { |c| c["codigo"] }, "C2",
                    "C002 debe encontrar a C2"
  end
end
