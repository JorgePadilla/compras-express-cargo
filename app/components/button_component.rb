class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-gradient-to-r from-cec-navy to-cec-navy-light text-white hover:from-cec-navy-light hover:to-cec-navy shadow-sm",
    secondary: "bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-100 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm",
    danger: "bg-cec-danger text-white hover:bg-red-600 shadow-sm",
    gold: "btn-gold-gradient text-cec-navy-dark font-semibold shadow-sm shadow-cec-gold/25",
    teal: "bg-cec-teal text-white hover:bg-cec-teal-dark shadow-sm",
    purple: "bg-cec-purple text-white hover:bg-cec-purple-dark shadow-sm shadow-cec-purple/25",
    ghost: "text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-800"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, href: nil, icon: nil, shortcut: nil, **attrs)
    @variant = variant.to_sym
    @size = size.to_sym
    @href = href
    @icon = icon
    @shortcut = shortcut # ej. "F10" — agrega data-shortcut + label visual "(F10)"
    @attrs = attrs
  end

  def call
    classes = "inline-flex items-center gap-2 rounded-lg font-medium transition-all duration-200 #{VARIANTS[@variant]} #{SIZES[@size]} #{@attrs.delete(:class)}"

    # Si hay shortcut, mergearlo en el data-attrs sin pisar otros data-* del caller.
    if @shortcut.present?
      existing_data = @attrs.delete(:data) || {}
      @attrs[:data] = existing_data.merge(shortcut: @shortcut)
    end

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
      content,
      shortcut_label
    ].compact)
  end

  # "(F10)" pequeño y semitransparente al final del label cuando hay shortcut.
  def shortcut_label
    return nil if @shortcut.blank?
    content_tag :span, "(#{@shortcut})",
                class: "ml-1 text-[10px] opacity-70 font-normal"
  end

  def icon_size
    @size == :sm ? "w-4 h-4" : "w-5 h-5"
  end
end
