require "test_helper"
require "view_component/test_helpers"

class DashboardHeroComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test "muestra saludo con el nombre del usuario" do
    user = users(:admin)
    render_inline(DashboardHeroComponent.new(
      user: user,
      health_status: { level: :ok, message: "Operación saludable" },
      time: Time.zone.local(2026, 4, 25, 9, 0, 0)
    ))

    assert_text "Buenos días"
    # Toma solo el primer nombre
    assert_text user.nombre.split.first
  end

  test "saludo de tarde" do
    render_inline(DashboardHeroComponent.new(
      user: users(:admin),
      health_status: { level: :ok, message: "ok" },
      time: Time.zone.local(2026, 4, 25, 15, 0, 0)
    ))

    assert_text "Buenas tardes"
  end

  test "saludo de noche" do
    render_inline(DashboardHeroComponent.new(
      user: users(:admin),
      health_status: { level: :ok, message: "ok" },
      time: Time.zone.local(2026, 4, 25, 22, 0, 0)
    ))

    assert_text "Buenas noches"
  end

  test "muestra mensaje del health status" do
    render_inline(DashboardHeroComponent.new(
      user: users(:admin),
      health_status: { level: :alert, message: "Crítico: 25 ventas pendientes" }
    ))

    assert_text "Crítico: 25 ventas pendientes"
  end
end
