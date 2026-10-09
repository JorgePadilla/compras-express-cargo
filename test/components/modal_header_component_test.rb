require "test_helper"

# PR-C29.12 · La franja de los modales: un tono por intención.
class ModalHeaderComponentTest < ViewComponent::TestCase
  test "cada tono pinta sus clases" do
    ModalHeaderComponent::TONOS.each do |tono, clases|
      render_inline(ModalHeaderComponent.new(tono: tono, titulo: "Hola"))
      clases.split.reject { |c| c.include?(":") }.each { |c| assert_selector "div.#{c.gsub('/', '\\/')}" }
    end
  end

  test "un tono que no existe revienta, no sale gris" do
    assert_raises(ArgumentError) { ModalHeaderComponent.new(tono: :naranja, titulo: "x") }
  end

  test "kicker, título con target, y lo que venga adentro" do
    render_inline(ModalHeaderComponent.new(tono: :bloqueo, kicker: "Problema",
                                           titulo_data: { medicion_target: "problemaTitulo" })) { "<p class='extra'>más</p>".html_safe }

    assert_selector "p.uppercase", text: "Problema"
    assert_selector "p[data-medicion-target='problemaTitulo']"
    assert_selector "p.extra", text: "más"
  end

  test "título como h3 con id, para aria-labelledby" do
    render_inline(ModalHeaderComponent.new(tono: :info, titulo: "Cambio de servicio", titulo_tag: :h3, titulo_id: "t1"))

    assert_selector "h3#t1", text: "Cambio de servicio"
  end

  test "cerrar pone la × con su acción" do
    render_inline(ModalHeaderComponent.new(tono: :info, titulo: "Mover", cerrar: "click->x#close"))

    assert_selector "button[aria-label='Cerrar'][data-action='click->x#close']"
  end
end
