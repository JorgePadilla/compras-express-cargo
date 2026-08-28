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

  private

  def ingresar(user)
    visit new_session_path
    # `wait` largo: el default de Capybara son 2s y el primer render en frío
    # los pierde — el login del test del WR ya andaba con `wait: 8` por esto.
    fill_in "email_address", with: user.email_address, wait: 10
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8
  end

  def abrir_etiquetar(tipo)
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      find("form[action='#{iniciar_sesion_etiquetar_path}'] button", text: tipo.nombre).click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  def campo(id) = find("##{id}")

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end

  # El window.open de la impresión es asíncrono: dispara con el turbo-stream
  # del guardado y la pestaña puede nacer DESPUÉS de que el ensure cerró las
  # que había. Esa huérfana le queda al siguiente test del worker — que
  # arranca con 2 ventanas y Capybara mirando la equivocada (así se cazó:
  # "ventanas=2" con el login sin campo de email). Todo test que guarda con
  # impresión la espera antes de cerrar.
  def esperar_pestana_de_impresion
    esperar(segundos: 5) { page.driver.browser.window_handles.size > 1 }
  end

  def cerrar_pestanas_extra
    b = page.driver.browser
    principal = b.window_handles.first
    b.window_handles[1..].to_a.each do |h|
      b.switch_to.window(h)
      b.close
    end
    b.switch_to.window(principal)
  end
end
