module SidebarHelper
  def sidebar_link(label, path, icon: nil, badge_count: nil)
    active = (path != "#" && current_page?(path)) rescue false
    content_tag(:li) do
      # `aria-current`: el link activo se marcaba solo con color y borde.
      link_to path, class: sidebar_link_classes(active),
              title: label,
              "aria-current": (active ? "page" : nil),
              data: { action: "click->sidebar#navigate" } do
        safe_join([
          icon ? heroicon(icon, variant: :outline, options: { class: "w-5 h-5 shrink-0", "aria-hidden": "true" }) : nil,
          content_tag(:span, label, class: "ml-3 sidebar-label whitespace-nowrap"),
          badge_count && badge_count > 0 ?
            content_tag(:span, class: "ml-auto sidebar-label bg-cec-gold text-cec-navy-dark text-xs font-bold px-2 py-0.5 rounded-full") do
              safe_join([ badge_count.to_s, content_tag(:span, " pendientes", class: "sr-only") ])
            end : nil
        ].compact)
      end
    end
  end

  # La lista de cada sección se nombra con su título: el lector de pantalla
  # anuncia «Miami, lista, 6 elementos» y no una lista suelta.
  def sidebar_section(title, &block)
    id = "sidebar-seccion-#{title.to_s.parameterize}"
    content_tag(:li, class: "pt-4 sidebar-section") do
      safe_join([
        content_tag(:p, title, id: id,
          class: "px-3 text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 sidebar-label whitespace-nowrap"),
        content_tag(:ul, class: "space-y-1", "aria-labelledby": id, &block)
      ])
    end
  end

  private

  def sidebar_link_classes(active)
    base = "sidebar-link flex items-center px-3 py-2 text-sm rounded-lg transition-colors"
    if active
      "#{base} active-link bg-white/10 text-white border-l-3 border-cec-gold"
    else
      "#{base} text-gray-300 hover:bg-white/5 hover:text-white"
    end
  end
end
