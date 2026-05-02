# Pagination wrapper que combina el `paginate` de Kaminari con un summary
# bilingüe ("Mostrando 1–25 de 142 pre-facturas") y un selector de items
# por página persistido en `?per=N`.
#
# Uso:
#   <%= render PaginationComponent.new(
#         collection: @pre_facturas,
#         label: "pre-facturas",
#         per_page_options: [10, 25, 50, 100]   # opcional
#       ) %>
#
# Edge cases:
#   - collection.total_count == 0 → muestra "Sin {label}", oculta controles.
#   - total_pages == 1 → muestra summary + selector (sin controles next/prev).
#   - per_page_options nil → no renderiza el selector.
class PaginationComponent < ViewComponent::Base
  DEFAULT_PER_PAGE_OPTIONS = [ 25, 50, 100, 200 ].freeze

  def initialize(collection:, label: "registros", per_page_options: DEFAULT_PER_PAGE_OPTIONS)
    @collection       = collection
    @label            = label.to_s
    @per_page_options = per_page_options
  end

  def total
    @total ||= @collection.respond_to?(:total_count) ? @collection.total_count : @collection.size
  end

  def empty?
    total.zero?
  end

  def single_page?
    !@collection.respond_to?(:total_pages) || @collection.total_pages.to_i <= 1
  end

  def current_page
    @collection.try(:current_page) || 1
  end

  def per_page
    @collection.try(:limit_value) || total
  end

  def first_index
    return 0 if empty?
    (current_page - 1) * per_page + 1
  end

  def last_index
    return 0 if empty?
    [ first_index + per_page - 1, total ].min
  end

  def show_per_page_selector?
    @per_page_options.present? && total > @per_page_options.first
  end

  # Genera URL con per actualizado, manteniendo otros params (q=, page=).
  def per_page_url(per)
    helpers.url_for(helpers.request.query_parameters.merge(per: per, page: 1))
  end
end
