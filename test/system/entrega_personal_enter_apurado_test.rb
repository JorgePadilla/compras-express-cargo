require "application_system_test_case"

# C20-10, el repro de Jorge:
#
#   > "Cuando ingresamos número, por ejemplo 6, en cliente tiene que buscarlo y
#   >  seleccionarlo rápido."
#   > "Cuando el cliente escribe 6 y luego Enter rápido, es más rápido que el
#   >  dropdown, y encima el dropdown se queda guindado porque el teclado es
#   >  más rápido."
#
# Antes, ese Enter se escapaba al formulario: el foco avanzaba con el cliente
# VACÍO y, dos décimas después, el dropdown se abría solo y sonaba el pito —
# así que el operario creía que había quedado puesto y F9 grababa sin cliente.
#
# La regla nueva la fijó Jorge: el Enter queda anotado y toma **el primero**,
# que es exactamente el que habría elegido de haber esperado.
#
# La gemela de `/etiquetar`: misma clase base, mismo bug, mismo arreglo.
class EntregaPersonalEnterApuradoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    visit new_entrega_personal_path
    assert_selector "form", wait: 5
  end

  test "el Enter que le gana al dropdown igual deja puesto al cliente" do
    demorar("/clientes/buscar", ms: 800)

    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.send_keys("2")
    campo.send_keys(:enter)

    # En este instante todavía no hay lista: el operario le ganó.
    assert page.has_no_selector?("[data-index]"), "la carrera no se produjo"

    esperar { cliente_elegido == clientes(:maria).id.to_s }
    assert_equal clientes(:maria).id.to_s, cliente_elegido,
                 "el Enter apurado se perdió y el paquete se iba a guardar sin cliente"
    assert page.has_no_selector?("[data-index]"), "el dropdown quedó guindado"
    assert_not_equal "clienteInput", foco_actual_target,
                     "después de elegir, el foco tiene que avanzar"
  end

  test "sin resultados no elige nada y el foco avanza igual" do
    demorar("/clientes/buscar", ms: 600)

    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.send_keys("ZZZZ")
    campo.send_keys(:enter)

    sleep 1.2
    assert_equal "", cliente_elegido
    assert page.has_no_selector?("[data-index]"), "la lista vacía quedó guindada"
  end

  test "seguir tecleando cancela el Enter que estaba esperando" do
    demorar("/clientes/buscar", ms: 700)

    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.send_keys("2")
    campo.send_keys(:enter)
    campo.send_keys("9")   # cambió de idea antes de que llegara

    sleep 1.5
    assert_not_equal clientes(:maria).id.to_s, cliente_elegido,
                     "cobró un Enter que hablaba de otra búsqueda"
  end

  test "Tab mientras la búsqueda viene en camino no deja la lista guindada" do
    demorar("/clientes/buscar", ms: 700)

    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.send_keys("2")
    campo.send_keys(:tab)

    sleep 1.5
    assert page.has_no_selector?("[data-index]"),
           "se fue del campo y el dropdown se abrió solo igual"
  end

  test "el pito suena una vez cuando el Enter apurado resuelve, y nunca sin resultados" do
    escuchar("entrega-personal:clienteEncontrado")
    demorar("/clientes/buscar", ms: 600)

    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.send_keys("2")
    campo.send_keys(:enter)
    esperar { cliente_elegido == clientes(:maria).id.to_s }

    assert_equal 1, eventos.count("entrega-personal:clienteEncontrado"),
                 "el pito ahora confirma que quedó puesto: ni mudo ni doble"
  end

  private

  def cliente_elegido
    page.evaluate_script("document.querySelector('[data-entrega-personal-target=clienteId]').value")
  end

  def foco_actual_target
    page.evaluate_script(
      "document.activeElement && (document.activeElement.dataset.entregaPersonalTarget || '')"
    ).to_s
  end

  def escuchar(*nombres)
    page.execute_script(<<~JS, nombres)
      window.__eventos = []
      arguments[0].forEach((n) => document.addEventListener(n, () => window.__eventos.push(n)))
    JS
  end

  def eventos
    page.evaluate_script("window.__eventos || []")
  end


  def esperar(segundos: 8)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.1 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end
end
