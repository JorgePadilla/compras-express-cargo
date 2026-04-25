require "test_helper"
require "view_component/test_helpers"

class QuickActionCardComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test "renders title, icon, and href" do
    render_inline(QuickActionCardComponent.new(
      title: "Etiquetar",
      href: "/etiquetar",
      icon: "tag"
    ))

    assert_selector "a[href='/etiquetar']"
    assert_text "Etiquetar"
    assert_selector "svg" # heroicon
  end

  test "renders subtitle when provided" do
    render_inline(QuickActionCardComponent.new(
      title: "Clientes",
      subtitle: "Lista y búsqueda",
      href: "/clientes",
      icon: "users"
    ))

    assert_text "Lista y búsqueda"
  end

  test "uses aria-label with title only when no subtitle" do
    render_inline(QuickActionCardComponent.new(
      title: "Solo Title",
      href: "/x",
      icon: "tag"
    ))

    assert_selector "a[aria-label='Solo Title']"
  end

  test "aria-label includes subtitle when present" do
    render_inline(QuickActionCardComponent.new(
      title: "Clientes",
      subtitle: "Lista y búsqueda",
      href: "/clientes",
      icon: "users"
    ))

    assert_selector "a[aria-label='Clientes — Lista y búsqueda']"
  end

  test "falls back to teal accent for invalid accent" do
    render_inline(QuickActionCardComponent.new(
      title: "Test",
      href: "/x",
      icon: "tag",
      accent: :nonexistent
    ))
    # Teal accent uses gradient pill class
    assert_selector ".bg-cec-teal-gradient", visible: :all
  end
end
