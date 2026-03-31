class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-cec-navy text-white hover:bg-cec-navy-light",
    secondary: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50",
    danger: "bg-cec-danger text-white hover:bg-red-600",
    gold: "bg-cec-gold text-cec-navy-dark hover:bg-cec-gold-dark font-semibold",
    ghost: "text-gray-600 hover:text-gray-900 hover:bg-gray-100"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, href: nil, icon: nil, **attrs)
    @variant = variant.to_sym
    @size = size.to_sym
    @href = href
    @icon = icon
    @attrs = attrs
  end

  def call
    classes = "inline-flex items-center gap-2 rounded-lg font-medium transition-colors #{VARIANTS[@variant]} #{SIZES[@size]} #{@attrs.delete(:class)}"

    if @href
      link_to @href, class: classes, **@attrs do
        inner_content
      end
    else
      content_tag :button, class: classes, **@attrs do
        inner_content
      end
    end
  end

  private

  def inner_content
    safe_join([
      @icon ? helpers.heroicon(@icon, variant: :outline, options: { class: icon_size }) : nil,
      content
    ].compact)
  end

  def icon_size
    @size == :sm ? "w-4 h-4" : "w-5 h-5"
  end
end
