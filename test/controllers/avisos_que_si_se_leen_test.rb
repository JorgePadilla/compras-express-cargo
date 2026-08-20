require "test_helper"

# Yusef, 2026-08-19, señalando la franja de contexto donde esto salía como texto
# al costado de la pantalla:
#
#   > *"No me da la información, **aquí necesitamos un modal**."*
#   > *"Estas informaciones **ellos no las leen**. Esto no lo leen, esto no lo
#   >  van a leer, olvídate."*
#   > *"No te voy a mentir, Jorge: **a puro huevos leen esto**."*
#
# Digitan de 500 a 1.000 paquetes al día mirando la pistola, no la pantalla.
#
# **Uno por cosa, no uno con todo.** Él arrancó pidiendo uno solo; Jorge
# argumentó que cada uno necesita su propia respuesta —retenido / se hizo /
# leída— y él aceptó: *"tenés razón, hacerlo así si querés"*.
class AvisosQueSiSeLeenTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    @motivo = motivos_retencion(:danado)
  end

  test "el escaneo trae la retencion con sus motivos por nombre" do
    # El id no sirve para mostrarlo: el que recibe necesita leer «paquete
    # dañado», no un número.
    pap = pre_alertar("1ZAVISO000000001", retener: true)

    json = escanear(pap.tracking)

    assert json["retener_miami"]
    assert_includes json["motivo_retencion_nombres"], @motivo.nombre
  end

  test "trae las tareas abiertas del cliente" do
    pap = pre_alertar("1ZAVISO000000002")
    tarea = Tarea.create!(cliente: clientes(:juan), titulo: "Consolidar con lo de la semana",
                          estado: "pendiente")

    json = escanear(pap.tracking)

    assert_equal [ tarea.id ], json["tareas"].map { |t| t["id"] }
    assert_equal "Consolidar con lo de la semana", json["tareas"].first["titulo"]
  end

  test "la tarea trae por dónde marcarla, que es por donde ya se marcaba" do
    # El checkbox de la franja registra **quién** la completó — la bitácora que
    # costó meses dejar bien. Un endpoint nuevo sería la gemela separada.
    pap = pre_alertar("1ZAVISO000000003")
    tarea = Tarea.create!(cliente: clientes(:juan), titulo: "x", estado: "pendiente")

    json = escanear(pap.tracking)

    assert_equal completar_tarea_path(tarea), json["tareas"].first["url"]
  end

  test "trae la instruccion del renglon y la nota del grupo" do
    # Son dos cosas y hasta ahora salía una sola.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Con notas", estado: "pre_alerta",
                           notas_grupo: "Todo esto va junto a Tegucigalpa")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1ZAVISO000000004", descripcion: "x",
                                          instrucciones: "El celular por Express")

    json = escanear(pap.tracking)

    textos = json["notas"].map { |n| n["texto"] }
    assert_includes textos, "El celular por Express"
    assert_includes textos, "Todo esto va junto a Tegucigalpa"
  end

  test "un paquete sin nada no trae avisos" do
    # Si no hay retención ni tareas ni notas, no sale ningún modal.
    pap = pre_alertar("1ZAVISO000000005")

    json = escanear(pap.tracking)

    assert_not json["retener_miami"]
    assert_empty json["tareas"]
    assert_empty json["notas"]
  end

  test "la pantalla los saca en fila, uno por cosa" do
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    encolar = src[/_encolarAvisos\(data\)\s*\{.*?\n  \}/m]
    assert encolar, "no se encontró la cola de avisos"

    assert_includes encolar, "data.retener_miami"
    assert_includes encolar, "data.tareas"
    assert_includes encolar, "data.notas"
    assert_includes encolar, "Se hizo"
    assert_includes encolar, "Leída"
  end

  test "y el «se hizo» va por el endpoint de siempre" do
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    confirmar = src[/avisoSi\(\)\s*\{.*?\n  \}/m]

    assert_includes confirmar, "completarUrl"
  end

  # ── La franja también ───────────────────────────────────────────────────

  test "la franja de contexto muestra la nota del grupo" do
    # Yusef: *"aquí están las notas del grupo y no sale… y el grupo sí tiene
    # notas"*. Leía solo las `instrucciones` del renglón.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Con nota de grupo", estado: "pre_alerta",
                           notas_grupo: "Ojo: son regalos de navidad")
    pa.pre_alerta_paquetes.create!(tracking: "1ZAVISO000000006", descripcion: "x")

    get panel_contexto_path(cliente_id: clientes(:juan).id, tracking: "1ZAVISO000000006")

    assert_response :success
    assert_match(/regalos de navidad/, response.body)
  end

  test "una pre-alerta sin nota de grupo no inventa nada" do
    pre_alertar("1ZAVISO000000007")

    get panel_contexto_path(cliente_id: clientes(:juan).id, tracking: "1ZAVISO000000007")

    assert_response :success
  end

  private

  def escanear(tracking)
    get check_tracking_paquetes_url(tracking: tracking), as: :json
    JSON.parse(response.body)
  end

  def pre_alertar(tracking, retener: false)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciado", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(
      tracking: tracking, descripcion: "Lo que viene", retener_miami: retener,
      motivo_retencion_ids: retener ? [ @motivo.id ] : []
    )
  end
end
