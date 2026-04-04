module SidebarHelper
  def sidebar_link(label, path, icon: nil, badge_count: nil)
    active = current_page?(path)
    content_tag(:li) do
      link_to path, class: sidebar_link_classes(active),
              data: { action: "click->sidebar#navigate" } do
        safe_join([
          icon ? heroicon(icon, variant: :outline, options: { class: "w-5 h-5 shrink-0" }) : nil,
          content_tag(:span, label, class: "ml-3"),
          badge_count && badge_count > 0 ?
            content_tag(:span, badge_count,
              class: "ml-auto bg-cec-gold text-cec-navy-dark text-xs font-bold px-2 py-0.5 rounded-full") : nil
        ].compact)
      end
    end
  end

  def sidebar_section(title, &block)
    content_tag(:li, class: "pt-4") do
      safe_join([
        content_tag(:p, title,
          class: "px-3 text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2"),
        content_tag(:ul, class: "space-y-1", &block)
      ])
    end
  end

  private

  def sidebar_link_classes(active)
    base = "flex items-center px-3 py-2 text-sm rounded-lg transition-colors"
    if active
      "#{base} bg-white/10 text-white border-l-3 border-cec-gold"
    else
      "#{base} text-gray-300 hover:bg-white/5 hover:text-white"
    end
  end
end
