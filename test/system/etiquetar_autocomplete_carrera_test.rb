require "application_system_test_case"

# C20-10: el dropdown de cliente le gana al teclado.
#
# Jorge, 2026-08-29: *"cuando el cliente escribe 6 y luego Enter rápido, es más
# rápido que el dropdown, y encima el dropdown se queda guindado porque el
# teclado es más rápido"*.
#
# Va como system test por lo mismo que `etiquetar_escaneo_rapido_test`: sin
# navegador no hay carrera que observar. Y como el servidor de test contesta
# más rápido de lo que Capybara teclea, la latencia se provoca a mano con
# `demorar` / `retener_la_primera`.
#
# Esta clase cubre la plomería (PR-C7.76): que una lista vieja no elija por el
# operario, que una respuesta tardía no repinte, y que F2 cancele. El Enter
# pendiente —el repro exacto de Jorge— va en su propia clase.
class EtiquetarAutocompleteCarreraTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "la lista que quedó vieja no elige por el operario" do
    # Modo 2: el campo dice «29» y la lista pintada todavía es la de «2».
    otro = Cliente.create!(codigo: "CEC-029", nombre: "Otro Cliente", apellido: "Distinto Apellido",
                           email: "otro29@example.com", activo: true)

    campo = find("[data-etiquetar-target=clienteInput]")
    campo.send_keys("2")
    assert_selector "[data-index]", wait: 5

    demorar("/clientes/buscar")
    campo.send_keys("9")
    campo.send_keys(:enter)

    # Con la lista vieja en pantalla, Enter NO puede elegir: habla de otra
    # búsqueda. Lo que importa acá es que NO quede el de la lista vieja
    # (`clientes(:maria)`, CEC-002). Que el Enter apurado termine poniendo el
    # correcto es el paso siguiente — el Enter pendiente de PR-C7.77.
    sleep 1.5
    assert_not_equal clientes(:maria).id.to_s, cliente_elegido,
                     "eligió el de la lista vieja: el «queda seleccionado» del audio"
    assert_includes [ "", otro.id.to_s ], cliente_elegido
  end

  test "la respuesta que llega tarde no repinta encima de la nueva" do
    # Modo 3, el mismo bug que PR-C6.21 arregló para el tracking.
    retener_la_primera("/clientes/buscar")

    campo = find("[data-etiquetar-target=clienteInput]")
    campo.send_keys("2")
    campo.set("")
    campo.send_keys("1")

    assert_selector "[data-index]", wait: 8
    primera = find("[data-index='0']").text
    esperar_respuesta_tardia

    assert_equal primera, find("[data-index='0']").text,
                 "la respuesta vieja repintó encima de la nueva"
  end

  test "F2 cierra el dropdown y cancela lo que venía en camino" do
    demorar("/clientes/buscar")
    find("[data-etiquetar-target=clienteInput]").send_keys("2")

    page.send_keys(:f2)

    # Después de que la respuesta demorada llegue, no puede haber repintado
    # nada: el formulario ya estaba limpio.
    sleep 1.5
    assert page.has_no_selector?("[data-index]"),
           "el dropdown repintó sobre el formulario ya limpio"
    assert_equal "", cliente_elegido
  end

  private

  def cliente_elegido
    page.evaluate_script("document.querySelector('[data-etiquetar-target=clienteId]').value")
  end


  def abrir_etiquetar
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end

  def esperar(segundos: 8)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.1 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end
end
