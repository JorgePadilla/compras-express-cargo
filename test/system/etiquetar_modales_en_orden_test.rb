require "application_system_test_case"

# C19-08. Jorge, 2026-08-28, probando después de la tanda del audio:
#
#   "Podemos hacer que los modales salgan en orden, actualmente salen
#    montados… pensaría que no tiene sentido que aparezca el modal [de aviso
#    junto a] 'Este paquete es de otro tipo de envío'."
#   "Si hay varias notas y alertas como la del paquete de otro tipo de envío
#    hay que mostrarlas en orden y no montadas, el orden que haga más sentido."
#
# El montaje: el conflicto de sesión es un overlay (div z-50) y los avisos son
# <dialog> nativos — top-layer, que pinta encima de cualquier z-index. Cuando
# el escaneo traía pre-alerta de otro tipo salían los dos a la vez, con el
# aviso tapando la decisión.
#
# El orden con sentido: el conflicto decide PRIMERO y sale solo — sus dos
# salidas abandonan el paquete en esta sesión, así que los avisos de
# retención/tareas/notas no tienen "después" acá: vuelven a salir enteros al
# escanear el paquete en la sesión correcta. Y la regla general que evita todo
# montaje: mientras haya una pregunta abierta, las teclas de guardar no actúan.
class EtiquetarModalesEnOrdenTest < ApplicationSystemTestCase
  setup do
    @cliente = clientes(:juan)
    ingresar(users(:digitador))
  end

  test "el conflicto de otro tipo de envio sale solo, sin avisos montados" do
    # Pre-alerta CER con retención anunciada; la sesión se abre en CER Legacy.
    # Antes: banner + beep de match + aviso NO DESPACHAR **encima** del
    # conflicto. Ahora: el conflicto, solo.
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer),
                           estado: "pre_alerta", titulo: "Conflicto de tipo")
    pa.pre_alerta_paquetes.create!(tracking: "1ZORDENCONFLICTO1",
                                   descripcion: "Perfumes", retener_miami: true)

    abrir_etiquetar(tipo_envios(:aereo))
    campo("paquete_tracking").send_keys("1ZORDENCONFLICTO1", :enter)

    assert_selector "[data-etiquetar-target='conflictoSesionModal']:not(.hidden)", wait: 5
    assert_text "pre-alerta de CER"
    assert_no_selector "dialog[data-etiquetar-target='avisoModal'][open]"
  end

  test "con un aviso abierto F9 no guarda; contestado, si" do
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo_envios(:aereo),
                           estado: "pre_alerta", titulo: "Retenida anunciada")
    pa.pre_alerta_paquetes.create!(tracking: "1ZORDENAVISO0001",
                                   descripcion: "Perfumes", retener_miami: true)

    abrir_etiquetar(tipo_envios(:aereo))
    # El peso primero: con el aviso abierto el formulario queda inerte.
    find("[data-caja-campo='peso']").set("10")
    campo("paquete_tracking").send_keys("1ZORDENAVISO0001", :enter)

    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "NO DESPACHAR"

    # El esperado de la pre-alerta ya existe: guardar acá lo ACTUALIZA a
    # recibido (C18-04), no crea paquete — por eso se mira el estado.
    esperado = Paquete.find_by!(tracking: "1ZORDENAVISO0001")

    page.send_keys(:f9)
    sleep 0.6
    assert_equal "pre_alerta_estado", esperado.reload.estado,
                 "F9 guardó por encima de la pregunta abierta"
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]"

    click_on "Retenido, confirmado"
    assert_no_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5

    page.send_keys(:f9)
    esperar { esperado.reload.estado == "recibido_miami" }
    assert_equal "recibido_miami", esperado.reload.estado,
                 "contestado el aviso, F9 tenía que guardar"

    esperar_pestana_de_impresion
  ensure
    cerrar_pestanas_extra
  end

  test "en EP, con la listita de retener abierta, F9 tampoco guarda" do
    # La gemela: las listitas (retener, política) también son <dialog>, y F9
    # por encima les guardaba el paquete con la pregunta sin contestar.
    visit new_entrega_personal_path
    assert_selector "form", wait: 5

    find("[data-entrega-personal-target='clienteInput']").fill_in with: "Juan"
    find("[data-entrega-personal-target='clienteDropdown'] *", match: :first, wait: 5).click
    select Proveedor.where(tipo: "entrega_personal").activos.ordered.first.nombre,
           from: "paquete[proveedor_id]"
    select Sucursal.de_recepcion.con_codigo_ep.first.nombre,
           from: "paquete[sucursal_recepcion_id]"
    select TipoEnvio.activos.order(:nombre).first.nombre, from: "paquete[tipo_envio_id]"
    fill_in "paquete[descripcion]", with: "Dos pares de zapatos"
    fill_in "paquete[peso]", with: "10"

    find("input[name='paquete[retener_miami]'][type='checkbox']").click
    assert_selector "dialog[open]", wait: 5

    antes = Paquete.count
    page.send_keys(:f9)
    sleep 0.6
    assert_equal antes, Paquete.count, "F9 guardó con la listita abierta"

    click_on "Cancelar"
    assert_no_selector "dialog[open]", wait: 5

    page.send_keys(:f9)
    esperar { Paquete.count == antes + 1 }
    assert_equal antes + 1, Paquete.count

    esperar_pestana_de_impresion
  ensure
    cerrar_pestanas_extra
  end

  # ── C20-13 · el duplicado también entra en la fila ──────────────────────
  #
  # Jorge, 2026-08-30: *"hay veces que retener en Miami y el cuadro de
  # tracking ya existe en el sistema salen los dos. Hagamos que el que tenga
  # más sentido salga primero: solo permitamos un modal a la vez."*
  #
  # Una respuesta sola nunca abre los dos: el montaje viene de dos consultas
  # en vuelo — el primario pre-alertado (avisos) y el secundario que ya existe
  # (duplicado). Sin latencia no hay carrera: `demorar` la fabrica.
  #
  # El orden lo decidió Jorge: conflicto > avisos > duplicado. Los avisos van
  # antes porque si el operario elige «Es actualización» ya no vuelven a
  # salir, y el NO DESPACHAR es el que Yusef pidió como modal (C14-02).

  TRACKING_T = "1ZORDENRETENIDO01".freeze
  TRACKING_S = "1ZORDENSECUNDARIO1".freeze

  test "el duplicado que llegó antes espera a que se contesten los avisos" do
    pre_alertar(TRACKING_T)
    recibido(TRACKING_S)
    abrir_etiquetar(tipo_envios(:cer))
    demorar("tracking=#{TRACKING_T}", ms: 1500)

    campo("paquete_tracking").send_keys(TRACKING_T, :enter)
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(TRACKING_S, :enter)

    # El secundario contesta primero: sale el duplicado.
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 3

    # Llega el primario con la retención: el aviso va primero, y el duplicado
    # se hace a un lado — a un lado, no debajo.
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "NO DESPACHAR"
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"

    click_on "Retenido, confirmado"

    # Contestado, el duplicado vuelve — con el foco adentro, como siempre.
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5
    assert_no_selector "dialog[data-etiquetar-target='avisoModal'][open]"
    # El foco va en el frame siguiente al unhide (C16-03): se espera, no se lee de una.
    foco_adentro = -> { page.evaluate_script("document.activeElement === document.querySelector('[data-etiquetar-target=duplicateUpdateBtn]')") }
    esperar(segundos: 3) { foco_adentro.call }
    assert foco_adentro.call, "el duplicado volvió sin el foco adentro: el Enter de la pistola caería en el formulario"

    click_on "Cancelar"
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
    assert_no_selector "dialog[open]"
  end

  test "el duplicado que llega con un aviso abierto no se monta: espera" do
    pre_alertar(TRACKING_T)
    recibido(TRACKING_S)
    abrir_etiquetar(tipo_envios(:cer))
    demorar("tracking=#{TRACKING_S}", ms: 2500)

    # El secundario primero, con su respuesta demorada: una vez que el aviso
    # abre, la página queda inerte y ya no se puede teclear nada.
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(TRACKING_S, :enter)
    campo("paquete_tracking").send_keys(TRACKING_T, :enter)

    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5
    sleep 2.5 # que la respuesta del secundario llegue con el aviso abierto
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]"
    assert page.has_no_selector?("[data-etiquetar-target='duplicateModal']:not(.hidden)"),
           "el duplicado se abrió debajo del aviso: los dos en pantalla"

    click_on "Retenido, confirmado"
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5
  end

  test "con el conflicto de sesión no queda ni el duplicado" do
    # C19-08: el conflicto decide solo. Ahora también se lleva el duplicado.
    pre_alertar(TRACKING_T, tipo: tipo_envios(:cem))
    recibido(TRACKING_S)
    abrir_etiquetar(tipo_envios(:cer))
    demorar("tracking=#{TRACKING_T}", ms: 1500)

    campo("paquete_tracking").send_keys(TRACKING_T, :enter)
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(TRACKING_S, :enter)
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 3

    assert_selector "[data-etiquetar-target='conflictoSesionModal']:not(.hidden)", wait: 5
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
    assert_no_selector "dialog[open]"

    find("[data-etiquetar-target=conflictoSesionDejarBtn]").click
    sleep 0.5
    assert_no_selector "[data-etiquetar-target='conflictoSesionModal']:not(.hidden)"
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
    assert_no_selector "dialog[open]"
  end

  test "el secundario de otro tipo de envío vuelve a avisar" do
    # Muerto desde PR-C7.62: `_revisarSecundarioConPreAlerta` llamaba a un
    # método que ese PR renombró, y el TypeError se iba al `.catch` sin que
    # nadie lo viera. La mitad que pidió Yusef —*"hay que avisarle al usuario:
    # hay una diferencia en el tipo de envío"*— llevaba semanas muda.
    pre_alertar(TRACKING_S, tipo: tipo_envios(:cem), retener: false)
    abrir_etiquetar(tipo_envios(:cer))

    campo("paquete_tracking").send_keys("1ZORDENLIBRE0001", :enter)
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(TRACKING_S, :enter)

    assert_selector "[data-etiquetar-target='conflictoSesionModal']:not(.hidden)", wait: 5
    assert_text "El tracking secundario tiene pre-alerta de CEM"
  end

  test "«Es duplicado real» sobre el secundario pone el sufijo en el secundario" do
    recibido(TRACKING_S)
    abrir_etiquetar(tipo_envios(:cer))

    campo("paquete_tracking").send_keys("1ZORDENLIBRE0002", :enter)
    page.send_keys(:f3)
    campo("paquete_tracking_secundario").send_keys(TRACKING_S, :enter)
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5

    click_on "Es duplicado real"

    assert_equal "1ZORDENLIBRE0002", campo("paquete_tracking").value, "el sufijo pisó el primario"
    assert_match(/\A#{TRACKING_S}[A-Z]\z/, campo("paquete_tracking_secundario").value)
  end

  test "Escape no contesta un aviso" do
    # C14-02: *"ellos no las leen"*. Las salidas de un aviso son sus botones
    # y F2; un Escape que lo cerraba en silencio dejaba además la fila trabada.
    pre_alertar(TRACKING_T)
    abrir_etiquetar(tipo_envios(:cer))

    campo("paquete_tracking").send_keys(TRACKING_T, :enter)
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5

    page.send_keys(:escape)
    sleep 0.3
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]"

    click_on "Retenido, confirmado"
    assert_no_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5
  end

  test "mientras otra pregunta esté abierta, el aviso espera y sale al cerrarla" do
    # La regla general: no solo el duplicado. La listita de retener, abierta a
    # mano mientras la consulta viene en camino, también hace esperar al aviso.
    pre_alertar(TRACKING_T)
    abrir_etiquetar(tipo_envios(:cer))
    demorar("tracking=#{TRACKING_T}", ms: 2500)

    campo("paquete_tracking").send_keys(TRACKING_T, :enter)
    find("input[name='paquete[retener_miami]'][type='checkbox']").click
    assert_selector "dialog[data-checkbox-modal-target=dialog][open]", wait: 3

    sleep 2.8 # la respuesta llega con la listita abierta
    assert_selector "dialog[data-checkbox-modal-target=dialog][open]"
    assert_no_selector "dialog[data-etiquetar-target='avisoModal'][open]"

    within("dialog[data-checkbox-modal-target=dialog]") { click_on "Cancelar" }
    assert_selector "dialog[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "NO DESPACHAR"
  end

  private

  def pre_alertar(tracking, tipo: tipo_envios(:cer), retener: true)
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo, estado: "pre_alerta",
                           titulo: "Orden de los modales")
    pa.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Perfumes", retener_miami: retener)
  end

  def recibido(tracking)
    Paquete.create!(tracking: tracking, cliente: @cliente, tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                    descripcion: "Perfumes", user: users(:digitador))
  end


  # Por `value` y no por texto: «CER» también matchea «CER Legacy».
  def abrir_etiquetar(tipo) = abrir_sesion_etiquetar(tipo)

  def campo(id) = find("##{id}")

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end
end
