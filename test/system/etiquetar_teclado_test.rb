require "application_system_test_case"

# PR-C6.3: en /etiquetar el Enter avanza de campo. Nunca guarda.
#
# Yusef, 2026-08-08, operando el sistema con Jorge al lado:
#
#   "El enter es como el siguiente campo."
#   "Grabar, no grabar — **seleccionar**."
#
# No es una preferencia de UX: **la pistola de código de barras dispara Enter**
# al terminar de leer, y eso no es configurable en la práctica. Miami trabaja
# solo con teclado — "usamos las manos para trabajar".
#
# El bug: `etiquetar_controller.js` solo interceptaba F2/F3/F4/F8/F9, así que
# ganaba el default del navegador y Enter enviaba el formulario. Cada escaneo
# grababa un paquete a medias — sin sucursal, sin peso, y asignado a quien la
# pre-alerta hubiera auto-rellenado.
#
# Esto va como system test porque es lo único que puede verlo: en un test de
# integración no hay navegador que decida qué hace un Enter.
class EtiquetarTecladoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "escanear un tracking con pre-alerta y darle Enter no graba nada" do
    # El repro exacto de Yusef, y por qué importa la pre-alerta: al salir del
    # campo, `checkTracking` encuentra la pre-alerta y **auto-rellena el
    # cliente**. Con tracking + cliente el paquete ya pasa las validaciones, así
    # que el Enter lo grababa entero — sin peso, sin sucursal, y "asignado a
    # María López cuando yo no se lo había puesto a nadie".
    #
    # Sin pre-alerta este test no probaría nada: el guardado fallaría igual por
    # falta de cliente.
    antes = Paquete.count

    campo("paquete_tracking").send_keys("1Z999PREALERT001", :enter)
    assert_selector "[data-etiquetar-target=preAlertaBanner]:not(.hidden)", wait: 5

    page.send_keys(:enter)
    page.send_keys(:enter)

    assert_equal antes, Paquete.count,
                 "Enter grabó un paquete a medias: la pistola dispara Enter en cada escaneo"
  end

  test "Enter mueve el foco al siguiente campo" do
    campo("paquete_tracking").send_keys("1Z999TECLADO002", :enter)

    assert_not_equal "paquete_tracking", foco_actual,
                     "el foco se quedó en el tracking en vez de avanzar"
  end

  test "Enter en la descripcion hace salto de linea, no avanza" do
    # La descripción es un textarea. Si el handler la tratara como un input
    # más, no se podría escribir un renglón nuevo.
    desc = campo("paquete_descripcion")
    desc.click
    desc.send_keys("primera", :enter, "segunda")

    assert_includes desc.value, "\n",
                    "en un textarea Enter tiene que ser salto de línea"
    assert_equal "paquete_descripcion", foco_actual
  end

  test "F2 limpia todo incluso despues de un intento fallido" do
    # El bug que Yusef reportó como "le doy F2 y no limpia". `formTarget.reset()`
    # no vacía el form: lo devuelve a los valores **renderizados**, y tras un
    # 422 esos son los que él acababa de escribir.
    #
    # Se simula el re-render llenando los campos y cambiando sus defaults, que
    # es exactamente lo que hace el servidor al responder con error.
    tracking = campo("paquete_tracking")
    tracking.send_keys("1Z999TECLADO003")
    page.execute_script(
      "document.getElementById('paquete_tracking').setAttribute('value', '1Z999TECLADO003')"
    )

    page.send_keys(:f2)

    assert_equal "", campo("paquete_tracking").value,
                 "F2 devolvió el formulario al valor renderizado en vez de vaciarlo"
  end

  test "F2 limpia los campos que se escribieron" do
    campo("paquete_tracking").send_keys("1Z999TECLADO004")
    campo("paquete_descripcion").send_keys("zapatos")

    page.send_keys(:f2)

    assert_equal "", campo("paquete_tracking").value
    assert_equal "", campo("paquete_descripcion").value
  end

  # Yusef apretó F10 sin pensarlo, y tiene razón por costumbre: F10 es guardar
  # en pre-facturas, ventas, caja y financiamientos. /etiquetar era el único
  # con F8 — que en el resto del sistema es "exportar a Excel".
  #
  # Se observa el evento `submit` del form en vez de contar paquetes: que el
  # `create` guarde bien ya lo cubre `etiquetar_controller_test`. Acá lo que
  # se prueba es que la tecla dispara el envío.
  test "F10 envia el formulario" do
    espiar_submit
    campo("paquete_tracking").send_keys("1Z999TECLADO005")

    page.send_keys(:f10)

    assert_equal 1, submits_observados, "F10 no envió el formulario"
  end

  test "F8 sigue funcionando mientras Miami se acostumbra" do
    espiar_submit
    campo("paquete_tracking").send_keys("1Z999TECLADO006")

    page.send_keys(:f8)

    assert_equal 1, submits_observados, "F8 dejó de guardar sin avisarle a Miami"
  end

  test "Enter no envia el formulario ni una sola vez" do
    # El mismo espía, del otro lado: por más Enters que reciba el form —que es
    # lo que hace la pistola en cada escaneo— no se envía nunca.
    espiar_submit

    campo("paquete_tracking").send_keys("1Z999TECLADO007", :enter)
    page.send_keys(:enter)
    page.send_keys(:enter)

    assert_equal 0, submits_observados,
                 "Enter envió el formulario: cada escaneo grabaría un paquete a medias"
  end

  # C16-04 · Yusef, 2026-08-25: "mirá a ver si lo podés lograr que quede al
  # mismo Tab: que vos lo seleccionás, se pase". Enter sobre el cliente elegía
  # y se quedaba; Tab pasaba pero sin elegir. Las dos teclas eligen y pasan.
  test "Enter sobre el cliente elige y pasa al siguiente campo" do
    cliente = find("[data-etiquetar-target=clienteInput]")
    cliente.send_keys("2")
    assert_selector "[data-index]", wait: 5

    cliente.send_keys(:enter)

    assert_equal clientes(:maria).id.to_s, cliente_id_elegido
    assert_not foco_en_el_cliente?, "eligió pero el foco se quedó en el cliente"
  end

  test "Tab sobre el cliente tambien elige, y pasa" do
    cliente = find("[data-etiquetar-target=clienteInput]")
    cliente.send_keys("2")
    assert_selector "[data-index]", wait: 5

    cliente.send_keys(:tab)

    assert_equal clientes(:maria).id.to_s, cliente_id_elegido,
                 "Tab cerró la lista sin elegir: el operario perdió el cliente que tenía resaltado"
    assert_not foco_en_el_cliente?
  end

  test "el modal de duplicado abre con el foco adentro" do
    # C16-03 · "le da Enter y se queda ahí". El overlay tapaba la pantalla pero
    # el cursor seguía en el formulario de atrás.
    #
    # Un paquete sin pre-alerta a propósito: el fixture `recibido` está
    # vinculado a una, y con pre-alerta lo que sale es el banner, no este modal.
    otro = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           tracking: "1ZYAEXISTEFOCO01", descripcion: "y",
                           estado: "recibido_miami", user: users(:digitador),
                           sucursal_recepcion: sucursales(:miami))

    campo("paquete_tracking").send_keys(otro.tracking, :enter)
    assert_selector "[data-etiquetar-target=duplicateModal]:not(.hidden)", wait: 5

    assert page.evaluate_script(<<~JS), "el foco no entró al modal de duplicado"
      document.activeElement === document.querySelector("[data-etiquetar-target=duplicateUpdateBtn]")
    JS
  end

  test "el atajo visible dice F10" do
    assert_text "Guardar"
    assert_selector "kbd", text: "F10"
  end

  test "F10 con el foco FUERA de un campo tampoco guarda dos veces" do
    # PR-BTN.4. Hay dos listeners de F10 sobre `document`:
    #
    #   · `etiquetar_controller` — llama a `submitForm()`
    #   · `keyboard_shortcuts_controller` — le hace click a `[data-shortcut]`
    #
    # `preventDefault()` no calla al otro (para eso haría falta
    # `stopImmediatePropagation`), así que si un botón de esta pantalla llevara
    # `shortcut: "F10"`, los dos correrían y el paquete se guardaría DOS veces.
    #
    # Por eso los botones de /etiquetar migraron con el `<kbd>` adentro del
    # bloque y nunca con `shortcut:`.
    #
    # El foco tiene que estar fuera de un campo: el handler global se abstiene
    # mientras se está escribiendo (`isEditing`), así que con el cursor en el
    # tracking este bug no se ve — que es justo lo que lo hace fácil de
    # reintroducir sin que nadie lo note.
    espiar_submit
    campo("paquete_tracking").send_keys("1Z999TECLADO008")
    page.execute_script("document.activeElement.blur()")

    page.send_keys(:f10)

    assert_equal 1, submits_observados,
                 "F10 disparó dos veces: algún botón está registrando data-shortcut"
  end

  private

  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5
  end

  # /etiquetar arranca preguntando el tipo de envío de la sesión; hasta que se
  # elige uno no existe el formulario.
  def abrir_etiquetar
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  def campo(id)
    find("##{id}")
  end

  def foco_actual
    page.evaluate_script("document.activeElement && document.activeElement.id")
  end

  def cliente_id_elegido
    page.evaluate_script("document.querySelector('[data-etiquetar-target=clienteId]').value")
  end

  def foco_en_el_cliente?
    page.evaluate_script(
      "document.activeElement === document.querySelector('[data-etiquetar-target=clienteInput]')"
    )
  end

  # Cuenta los `submit` del formulario sin dejar que salgan: así el test mide
  # la tecla y no depende de que el `create` pase validaciones.
  def espiar_submit
    page.execute_script(<<~JS)
      window.__submits = 0
      document.querySelector("form[data-etiquetar-target=form]")
              .addEventListener("submit", function (e) {
                e.preventDefault()
                window.__submits += 1
              })
    JS
  end

  def submits_observados
    page.evaluate_script("window.__submits")
  end
end
