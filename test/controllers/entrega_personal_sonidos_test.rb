require "test_helper"

# C16-02: el pito de «el cliente apareció» es de las dos pantallas con
# autocomplete de cliente, no solo de /etiquetar. Yusef, Conversación 4: "esto
# es en Etiquetar y en Entrega Personal". El dispatch vive en la base que
# comparten (`cliente_autocomplete.js`), así que ninguna se puede olvidar —
# pero el cableado en la vista sí, y eso es lo que fija este test.
class EntregaPersonalSonidosTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    get new_entrega_personal_url
    @body = response.body
  end

  test "el cliente que aparece en la lista suena igual que en etiquetar" do
    assert_match(/entrega-personal:clienteEncontrado->audio#success/, @body)
  end

  test "el guardado sigue sonando" do
    assert_match(/entrega-personal:success->audio#success/, @body)
  end

  test "no cablea el tracking libre: aca no hay chequeo de tracking" do
    assert_no_match(/entrega-personal:trackingLibre/, @body)
  end
end
