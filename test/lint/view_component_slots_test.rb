require "test_helper"

# Lint: no renderizar partials dentro de un slot de ViewComponent.
#
# El bloque de `with_action { ... }` se ejecuta en el contexto del componente,
# donde los helpers de la APP (`heroicon`, y cualquier cosa de app/helpers) NO
# existen — ViewComponent::Base no los incluye. El resultado es un
# NoMethodError en runtime:
#
#     undefined method `heroicon' for an instance of #<Class:0x...>
#
# Lo traicionero es que **el entorno de test no lo reproduce**: ahí el bloque
# resuelve contra la vista y pasa. Solo revienta en desarrollo y producción,
# así que un test de integración da falsa confianza. Por eso el guard es
# estático.
#
# La forma correcta es renderizar el partial ANTES, en la vista, y pasarle al
# slot el HTML ya resuelto:
#
#     <% mi_html = render("shared/algo") %>
#     <%= render PageHeaderComponent.new(...) do |header|
#       header.with_action { mi_html }
#     end %>
class ViewComponentSlotsTest < ActiveSupport::TestCase
  VIEWS = Rails.root.join("app/views")

  # Solo los PARTIALS son problema: `with_xxx { render "shared/algo" }` o
  # `render partial: "..."`. Renderizar otro ViewComponent adentro de un slot
  # —`with_badge { render StatusBadgeComponent.new(...) }`— es válido, porque
  # un componente no depende de los helpers de la app.
  RENDER_EN_SLOT = /with_\w+\s*(?:\{|do)\s*render[\s(]*(?:partial:|["':])/

  test "ningun slot de ViewComponent renderiza un partial adentro del bloque" do
    ofensas = []

    Dir.glob(VIEWS.join("**/*.erb")).each do |archivo|
      File.readlines(archivo).each_with_index do |linea, i|
        next unless linea.match?(RENDER_EN_SLOT)

        ofensas << "#{Pathname.new(archivo).relative_path_from(Rails.root)}:#{i + 1}\n    #{linea.strip}"
      end
    end

    assert_empty ofensas, <<~MSG
      Se renderiza un partial dentro de un slot de ViewComponent. Los helpers
      de la app no existen en ese contexto y revienta en desarrollo (el test
      environment NO lo reproduce).

      Renderizá el partial antes y pasale el HTML al slot:

        <% mi_html = render("shared/algo") %>
        header.with_action { mi_html }

      Encontrado en:
      #{ofensas.join("\n  ")}
    MSG
  end
end
