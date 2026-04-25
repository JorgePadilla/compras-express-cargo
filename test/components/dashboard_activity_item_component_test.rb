require "test_helper"
require "view_component/test_helpers"

class DashboardActivityItemComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test "renderiza link, eyebrow, title e iniciales" do
    render_inline(DashboardActivityItemComponent.new(
      href: "/paquetes/1",
      avatar_name: "Juan Carlos Perez",
      eyebrow: "PQ-0001",
      title: "Juan Carlos Perez · 1Z999",
      time: 2.minutes.ago
    ))

    assert_selector "a[href='/paquetes/1']"
    assert_text "PQ-0001"
    assert_text "Juan Carlos Perez · 1Z999"
    assert_text "JC" # iniciales (default max=2)
    assert_text "hace"
  end

  test "renderiza badge slot" do
    render_inline(DashboardActivityItemComponent.new(
      href: "/x", avatar_name: "Test User", eyebrow: "X", title: "y"
    )) do |c|
      c.with_badge { "<span class='custom-badge'>BADGE</span>".html_safe }
    end

    assert_selector ".custom-badge"
  end

  test "no muestra tiempo si es nil" do
    render_inline(DashboardActivityItemComponent.new(
      href: "/x", avatar_name: "A", eyebrow: "y", title: "z", time: nil
    ))

    assert_no_text "hace"
  end
end
