require "application_system_test_case"

# PR-C6.21: dos escaneos seguidos no se pisan.
#
# Yusef, 2026-08-08, con la pistola en la mano:
#
#   "Le di enter y no lo reconoce... **le di enter rápido y mete rápido**,
#    aquí es donde tenés que ver cómo integrar eso."
#   "Tiene que ser **rápido**."
#
# El `fetch` de `checkTracking` salía sin cancelar el anterior y su `.then`
# nunca verificaba que el campo siguiera diciendo lo mismo. La pistola dispara
# Enter sola, así que escanear A y enseguida B dejaba la respuesta de A
# pisando el formulario de B: **el cliente de A auto-rellenado sobre el
# paquete de B**. Eso se factura mal.
#
# Va como system test porque es una carrera entre dos respuestas del
# servidor — sin navegador no hay carrera que observar.
class EtiquetarEscaneoRapidoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "la respuesta que llega tarde no pisa el escaneo siguiente" do
    # Dos pre-alertas de clientes distintos: cada una auto-rellena el suyo, así
    # que se puede ver de quién quedó el formulario.
    primero = pre_alerta_paquetes(:pap_sin_vincular)   # cliente juan
    segundo = pre_alerta_paquetes(:pap_maria)          # cliente maria

    # Mandar los dos escaneos "rápido" no alcanza: Selenium tarda más que el
    # servidor, así que la primera respuesta siempre llega antes y no hay
    # carrera que observar. Se fuerza el reordenamiento reteniendo la primera
    # respuesta — que es literalmente el escenario que describió Yusef:
    # "pueda que tenga un pequeño lag de milisegundos".
    retener_la_primera_respuesta

    campo = campo("paquete_tracking")
    campo.send_keys(primero.tracking, :enter)
    campo.set("")
    campo.send_keys(segundo.tracking, :enter)

    # La segunda vuelve enseguida y pinta a María.
    assert_selector "[data-etiquetar-target=preAlertaBanner]:not(.hidden)", wait: 5
    assert_match(/#{segundo.pre_alerta.cliente.nombre}/i,
                 find("[data-etiquetar-target=clienteInput]").value)

    # Ahora sí llega la primera, la de Juan, tarde.
    assert page.evaluate_async_script(<<~JS), "la respuesta retenida nunca llegó"
      const done = arguments[0]
      const esperar = () => window.__respuestaTardia ? done(true) : setTimeout(esperar, 50)
      esperar()
    JS

    cliente = find("[data-etiquetar-target=clienteInput]").value
    assert_match(/#{segundo.pre_alerta.cliente.nombre}/i, cliente,
                 "la respuesta vieja pisó el formulario: quedó el cliente del escaneo anterior")
    assert_no_match(/#{primero.pre_alerta.cliente.nombre}/i, cliente)
  end

  test "despues de limpiar, el mismo tracking se vuelve a consultar" do
    # El dedupe que evita la consulta doble (Enter + blur) no puede dejar
    # mudo un re-escaneo legítimo después de F2.
    tracking = pre_alerta_paquetes(:pap_sin_vincular).tracking

    campo("paquete_tracking").send_keys(tracking, :enter)
    assert_selector "[data-etiquetar-target=preAlertaBanner]:not(.hidden)", wait: 5

    page.send_keys(:f2)
    assert_no_selector "[data-etiquetar-target=preAlertaBanner]:not(.hidden)", wait: 5

    campo("paquete_tracking").send_keys(tracking, :enter)
    assert_selector "[data-etiquetar-target=preAlertaBanner]:not(.hidden)", wait: 5
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

  # Retiene la PRIMERA consulta de tracking hasta que la segunda ya volvió, y
  # avisa cuando por fin la suelta. Es el orden de llegada que produce la
  # latencia real; sin esto la carrera no es observable desde Selenium.
  def retener_la_primera_respuesta
    page.execute_script(<<~JS)
      window.__respuestaTardia = false
      const original = window.fetch
      let consultas = 0
      window.fetch = function (...args) {
        const promesa = original.apply(this, args)
        if (!String(args[0]).includes("check_tracking")) return promesa
        consultas += 1
        if (consultas !== 1) return promesa
        return promesa.then((r) => new Promise((resolver) => {
          setTimeout(() => { window.__respuestaTardia = true; resolver(r) }, 1500)
        }))
      }
    JS
  end
end
