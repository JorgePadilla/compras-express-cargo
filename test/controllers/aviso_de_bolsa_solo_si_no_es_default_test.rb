require "test_helper"

# Yusef, 2026-08-19, mirando el aviso de «guardar en la bolsa de San Pedro Sula»:
#
#   > *"Esa de San Pedro Sula hay que eliminarlo, porque es el default."*
#   > *"El cerebro trabaja en default. Cuando querés que haga una cosa diferente
#   >  al default, tenés que ponerle la nota que es diferente."*
#
# El 80% de la carga se queda en San Pedro. Un aviso que sale siempre deja de
# leerse — y entonces tampoco se lee el día que dice Tegucigalpa, que era el
# único día en que importaba.
class AvisoDeBolsaSoloSiNoEsDefaultTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    @default = sucursales(:zeron_sps)
    @default.update!(retiro_por_defecto: true)
    @otra = sucursales(:humuya_tgu)
  end

  test "quien retira en la de siempre no dispara el aviso" do
    clientes(:juan).update!(sucursal_retiro: @default)

    assert clientes(:juan).retira_en_la_de_por_defecto?
  end

  test "quien retira en otra, sí" do
    clientes(:juan).update!(sucursal_retiro: @otra)

    assert_not clientes(:juan).retira_en_la_de_por_defecto?
  end

  test "sin sucursal asignada tampoco cuenta como la de siempre" do
    # De ese cliente no se sabe a dónde va, y ahí el aviso sirve.
    clientes(:juan).update!(sucursal_retiro: nil)

    assert_not clientes(:juan).retira_en_la_de_por_defecto?
  end

  test "el escaneo de una pre-alerta lo dice" do
    clientes(:juan).update!(sucursal_retiro: @default)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "x", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1ZBOLSA000000001", descripcion: "x")

    get check_tracking_paquetes_url(tracking: pap.tracking), as: :json

    assert JSON.parse(response.body)["cliente_retiro_por_defecto"]
  end

  test "y la búsqueda de clientes también" do
    # Los dos caminos fijan el cliente en la pantalla, y ya se separaron una vez
    # por olvidar uno: Yusef reportó dos veces que no le avisaba la sucursal.
    clientes(:juan).update!(sucursal_retiro: @default)

    get buscar_clientes_url(q: clientes(:juan).codigo), as: :json

    fila = JSON.parse(response.body).find { |c| c["id"] == clientes(:juan).id }
    assert fila["retiro_por_defecto"]
  end

  test "la pantalla se calla solo para la de siempre" do
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    metodo = src[/_avisarSucursalAlFinal\(\)\s*\{.*?\n  \}/m]

    assert_includes metodo, "_avisarLaBolsa"
  end

  test "el banner pasivo se queda" do
    # Es el que él dio por bueno —*"sí me dice el TEGUS, excelente"*— y no
    # interrumpe a nadie. Lo que deja de salir es el modal que tapa la pantalla.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read
    metodo = src[/_mostrarSucursal\(sucursal, esLaDeSiempre = false\)\s*\{.*?\n  \}/m]
    assert metodo, "no se encontró _mostrarSucursal"

    assert_includes metodo, "sucursalBannerTarget.classList.remove"
  end

  test "se puede cambiar cuál es la de siempre sin tocar código" do
    # La pantalla de sucursales es de admin: el que recibe en Miami no decide a
    # dónde va la carga de todos.
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    patch sucursal_url(@otra), params: { sucursal: { retiro_por_defecto: "1" } }

    assert @otra.reload.retiro_por_defecto?
  end
end
