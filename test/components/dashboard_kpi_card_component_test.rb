require "test_helper"
require "view_component/test_helpers"

class DashboardKpiCardComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test "renderiza title, count-up target y delta" do
    render_inline(DashboardKpiCardComponent.new(
      title: "Ingresos hoy",
      value: 1234.56,
      decimals: 2,
      prefix: "L ",
      icon: "banknotes",
      accent: :teal,
      delta: { pct: 12, direction: :up, label_short: "+12%" },
      series: [ 1, 2, 3, 4, 5, 6, 7 ]
    ))

    assert_text "Ingresos hoy"
    assert_selector "[data-controller='count-up'][data-count-up-target-value='1234.56']"
    assert_text "+12%"
  end

  test "no renderiza sparkline si la serie tiene menos de 2 puntos" do
    render_inline(DashboardKpiCardComponent.new(
      title: "X", value: 1, icon: "tag", accent: :navy,
      delta: { pct: 0, direction: :flat, label_short: "—" }, series: [ 1 ]
    ))

    assert_no_selector "polyline"
  end

  test "renderiza sparkline cuando hay serie" do
    render_inline(DashboardKpiCardComponent.new(
      title: "X", value: 5, icon: "tag", accent: :gold,
      delta: { pct: 0, direction: :flat, label_short: "—" }, series: [ 1, 3, 2, 5, 4, 6, 5 ]
    ))

    assert_selector "polyline"
    assert_selector "polygon"
  end

  test "fallback a teal con accent inválido" do
    render_inline(DashboardKpiCardComponent.new(
      title: "X", value: 1, icon: "tag", accent: :wrong,
      delta: { pct: 0, direction: :flat, label_short: "—" }
    ))

    assert_selector ".bg-cec-teal-gradient"
  end
end
