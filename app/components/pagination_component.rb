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
#   - página fuera de rango (`?page=99`) → un link a la primera.
#
# PR-PAG.1 · **Arriba y abajo, el mismo.** Jorge, 2026-10-15: *"make sure the
# pagination is visible in the bottom and top, try to make pagination all the
# same in all views"*. Cada lista lo dibuja dos veces —`posicion: :arriba`
# encima de la tabla y el de siempre abajo— y el margen lo pone el componente,
# no la vista: así no hay una pantalla con `mt-4`, otra con `mt-6` y otra sin
# nada. `test/lint/paginacion_arriba_y_abajo_test.rb` lo hace cumplir.
#
# El de arriba no se dibuja cuando todo entra en una página y no hay selector:
# repetiría el «Mostrando N» del subtítulo, y el de abajo sigue estando.
class PaginationComponent < ViewComponent::Base
  DEFAULT_PER_PAGE_OPTIONS = [ 25, 50, 100, 200 ].freeze
  POSICIONES = %i[arriba abajo].freeze

  def initialize(collection:, label: "registros", per_page_options: DEFAULT_PER_PAGE_OPTIONS, posicion: :abajo)
    @collection       = collection
    @label            = label.to_s
    @per_page_options = per_page_options
    @posicion         = POSICIONES.include?(posicion) ? posicion : :abajo
  end

  def arriba? = @posicion == :arriba

  def render?
    return true unless arriba?

    !empty? && (!single_page? || show_per_page_selector?)
  end

  # Dos `nav` en la misma página necesitan nombres distintos: el lector de
  # pantalla los lista como puntos de referencia.
  def nav_label = "Paginación, #{@posicion}"

  def margen = arriba? ? "mb-3" : "mt-4"

  def selector_id = "por_pagina_#{@posicion}"

  # `?page=99` con 30 registros: la página viene vacía pero el total no.
  def fuera_de_rango?
    !empty? && @collection.respond_to?(:out_of_range?) && @collection.out_of_range?
  end

  def primera_pagina_url
    helpers.url_for(helpers.request.query_parameters.merge(page: 1))
  end

  # Las opciones, más la de la URL si no es una de ellas (`?per=10`): si no,
  # el select no marca ninguna y dice «25» mientras se ven 10.
  def opciones_por_pagina
    (@per_page_options | [ per_page ]).sort
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
