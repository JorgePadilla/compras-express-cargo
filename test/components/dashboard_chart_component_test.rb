require "test_helper"
require "view_component/test_helpers"

class DashboardChartComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  def series(*counts)
    counts.each_with_index.map do |c, i|
      day = Date.current - (counts.length - 1 - i)
      { fecha: day, label: day.strftime("%a %d"), paquetes: c }
    end
  end

  test "calcula total, pico y promedio" do
    render_inline(DashboardChartComponent.new(series: series(1, 3, 5, 7, 9, 11, 13)))

    assert_text "Total"
    assert_text "Pico"
    assert_text "Promedio"
    assert_text "49"  # 1+3+5+7+9+11+13
    assert_text "13"  # peak
    assert_text "7"   # avg = 49/7
  end

  test "renderiza la curva y el área cuando hay datos" do
    render_inline(DashboardChartComponent.new(series: series(2, 4, 6, 8, 10, 12, 14)))

    assert_selector "svg path", count: 2 # area + line
    assert_selector "circle"             # último punto pulsante
  end

  test "muestra empty state si no hay datos" do
    render_inline(DashboardChartComponent.new(series: []))
    assert_text "Sin datos"
    assert_no_selector "svg"
  end
end
