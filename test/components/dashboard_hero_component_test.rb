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

  # PR-C29.16 · El ícono de «Signos del servidor», a la derecha.
  test "con signos sale el ícono, con el color de su semáforo" do
    { bien: "bg-cec-teal", mirar: "bg-cec-gold", problema: "bg-red-600" }.each do |nivel, color|
      render_inline(DashboardHeroComponent.new(user: users(:admin), health_status: nil, signos: nivel))
      assert_selector "a[aria-label^='Signos del servidor'] span.#{color}"
    end
  end

  test "sin signos (quien no puede entrar) el ícono no sale" do
    render_inline(DashboardHeroComponent.new(user: users(:admin), health_status: nil))
    assert_no_selector "a[aria-label^='Signos del servidor']"
  end
end
