require "application_system_test_case"

# PR-C6.32: buscar el cliente en Entrega Personal se comporta igual que en
# /etiquetar.
#
# Jorge, 2026-08-09: "en entrega personal, cuando seleccionamos el cliente es
# distinto de lo que tenemos en etiquetar. Debería ser el mismo comportamiento:
# el dropdown preseleccionado y la búsqueda de un caracter".
#
# Los dos son la misma tarea —el operario tiene el código del cliente y lo
# teclea— pero cada pantalla tenía su propia copia del autocomplete, y a la de
# EP nunca le llegaron los arreglos:
#
#   · PR-C6.16 le bajó el mínimo a un dígito en etiquetar. Yusef: "solo le
#     ponían el dos, ponele que el mío es el seis, y ya con eso cae".
#   · El mismo PR dejó el primer resultado preseleccionado, para confirmarlo
#     con Enter sin soltar el teclado.
#
# Es la tercera vez que la misma duplicación muerde: antes fue el peso por
# caja y el modal de F9 (PR-C6.31). Por eso este PR no copia el
# comportamiento — mueve el autocomplete a una base compartida.
#
# Este archivo es un espejo de `etiquetar_busqueda_cliente_test.rb` a
# propósito: si las dos pantallas tienen que comportarse igual, sus tests
# tienen que poder leerse en paralelo.
class EntregaPersonalBusquedaClienteTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    visit new_entrega_personal_path
    assert_selector "[data-entrega-personal-target=clienteInput]", wait: 5
  end

  test "un solo digito abre la lista" do
    buscar("2")

    assert_selector "[data-index]", wait: 5
    assert_text "CEC-002"
  end

  test "el que uno busca sale primero y preseleccionado" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    primero = all("[data-index]").first
    assert_equal "CEC-002", primero.find("span.font-mono").text
    assert primero[:class].include?("bg-cec-teal/10"), "el primero no quedó preseleccionado"
  end

  test "Enter toma el preseleccionado sin usar el mouse" do
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-entrega-personal-target=clienteInput]").send_keys(:enter)

    assert_equal clientes(:maria).id.to_s,
                 page.evaluate_script("document.querySelector('[data-entrega-personal-target=clienteId]').value")
  end

  test "las flechas mueven la seleccion" do
    buscar("cec")
    assert_selector "[data-index]", wait: 5
    skip "se necesitan al menos dos clientes en el resultado" if all("[data-index]").size < 2

    find("[data-entrega-personal-target=clienteInput]").send_keys(:arrow_down)

    assert all("[data-index]")[1][:class].include?("bg-cec-teal/10"),
           "la flecha abajo no movió la selección"
  end

  test "una sola letra NO abre la lista" do
    buscar("a")

    assert_no_selector "[data-index]", wait: 2
  end

  test "al elegirlo se carga su franja de contexto" do
    # Lo que EP hace de más que etiquetar y no se puede perder en el camino.
    buscar("2")
    assert_selector "[data-index]", wait: 5

    find("[data-entrega-personal-target=clienteInput]").send_keys(:enter)

    assert_selector "turbo-frame#panel_contexto[src*='cliente_id']", visible: :all, wait: 5
  end

  private

  def buscar(texto)
    campo = find("[data-entrega-personal-target=clienteInput]")
    campo.click
    campo.send_keys(texto)
  end
end
