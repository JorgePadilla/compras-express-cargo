require "test_helper"

class RowActionComponentTest < ViewComponent::TestCase
  test "edit action renders pencil icon link" do
    render_inline(RowActionComponent.new(action: :edit, href: "/clientes/1/edit", label: "Editar cliente"))
    assert_selector "a[href='/clientes/1/edit'][title='Editar cliente']"
    assert_selector "svg" # heroicon
  end

  test "delete action renders trash icon button with turbo_confirm" do
    render_inline(RowActionComponent.new(action: :delete, href: "/clientes/1", label: "Borrar cliente"))
    assert_selector "form[action='/clientes/1'][method='post']"
    assert_selector "input[name='_method'][value='delete']", visible: :hidden
    assert_selector "button[data-turbo-confirm]"
  end

  test "view action renders eye icon link" do
    render_inline(RowActionComponent.new(action: :view, href: "/clientes/1", label: "Ver cliente"))
    assert_selector "a[href='/clientes/1'][title='Ver cliente']"
  end

  test "disabled state renders span without href" do
    render_inline(RowActionComponent.new(action: :edit, href: "/clientes/1/edit", disabled: true, label: "Editar cliente"))
    assert_selector "span[role='button'][aria-disabled='true']"
    assert_no_selector "a[href]"
  end

  test "custom confirm overrides default" do
    render_inline(RowActionComponent.new(action: :delete, href: "/x", confirm: "Texto custom", label: "Borrar"))
    assert_selector "button[data-turbo-confirm='Texto custom']"
  end

  test "pdf action opens with target attribute when print" do
    render_inline(RowActionComponent.new(action: :print, href: "/x/print", label: "Imprimir"))
    assert_selector "a[target='_blank']"
  end

  test "raises on unknown action" do
    assert_raises(KeyError) do
      RowActionComponent.new(action: :unknown, href: "/x")
    end
  end
end
