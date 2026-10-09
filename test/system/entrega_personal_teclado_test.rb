require "application_system_test_case"

# C16-04: la navegación por Enter de /etiquetar llega a su gemela.
#
# /entrega_personal no tenía `formKeydown`: Enter enviaba el formulario, y al
# hacer que elegir un cliente con el teclado avance de campo, EP habría
# quedado con Tab avanzando y Enter no — la divergencia entre gemelas que este
# repo ya pagó cuatro veces. Yusef, Conversación 4: "esto es en Etiquetar y en
# Entrega Personal".
#
# Espejo de `etiquetar_teclado_test.rb` a propósito.
class EntregaPersonalTecladoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    visit new_entrega_personal_path
    assert_selector "[data-entrega-personal-target=clienteInput]", wait: 5
  end

  test "Enter no envia el formulario" do
    espiar_submit

    cliente.send_keys("2")
    assert_selector "[data-index]", wait: 5
    cliente.send_keys(:enter)
    page.send_keys(:enter)
    page.send_keys(:enter)

    assert_equal 0, submits_observados, "Enter envió el formulario de Entrega Personal"
  end

  test "Enter sobre el cliente elige y pasa al siguiente campo" do
    cliente.send_keys("2")
    assert_selector "[data-index]", wait: 5

    cliente.send_keys(:enter)

    assert_equal clientes(:maria).id.to_s, cliente_id_elegido
    assert_not foco_en_el_cliente?, "eligió pero el foco se quedó en el cliente"
  end

  test "Tab sobre el cliente tambien elige, y pasa" do
    cliente.send_keys("2")
    assert_selector "[data-index]", wait: 5

    cliente.send_keys(:tab)

    assert_equal clientes(:maria).id.to_s, cliente_id_elegido
    assert_not foco_en_el_cliente?
  end

  private

  def cliente = find("[data-entrega-personal-target=clienteInput]")

  def cliente_id_elegido
    page.evaluate_script("document.querySelector('[data-entrega-personal-target=clienteId]').value")
  end

  def foco_en_el_cliente?
    page.evaluate_script(
      "document.activeElement === document.querySelector('[data-entrega-personal-target=clienteInput]')"
    )
  end

  def espiar_submit
    page.execute_script(<<~JS)
      window.__submits = 0
      document.querySelector("form[data-entrega-personal-target=form]")
              .addEventListener("submit", function (e) {
                e.preventDefault()
                window.__submits += 1
              })
    JS
  end

  def submits_observados = page.evaluate_script("window.__submits")
end
