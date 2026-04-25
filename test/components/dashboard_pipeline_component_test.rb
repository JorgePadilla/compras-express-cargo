require "test_helper"
require "view_component/test_helpers"

class DashboardPipelineComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test "renderiza los 4 stages con count-up" do
    render_inline(DashboardPipelineComponent.new(
      en_bodega: 84, en_transito: 12, disponibles: 23, pendientes: 7
    ))

    assert_text "En bodega"
    assert_text "En tránsito"
    assert_text "Listos entrega"
    assert_text "Ventas pendientes"
    # Cada stage trae count-up
    assert_selector "[data-count-up-target-value='84']"
    assert_selector "[data-count-up-target-value='12']"
    assert_selector "[data-count-up-target-value='23']"
    assert_selector "[data-count-up-target-value='7']"
  end

  test "renderiza barras con width proporcional al máx" do
    render_inline(DashboardPipelineComponent.new(
      en_bodega: 100, en_transito: 0, disponibles: 50, pendientes: 25
    ))
    # El stage con max=100 → 100%; otros proporcionales (mínimo 4%)
    assert_match(/width: 100%/, page.native.to_html)
    assert_match(/width: 50%/,  page.native.to_html)
    assert_match(/width: 25%/,  page.native.to_html)
    assert_match(/width: 4%/,   page.native.to_html) # 0 escala a min 4%
  end
end
