class EmptyStateComponent < ViewComponent::Base
  renders_one :action

  # `titulo_tag`: PR-A11Y.2. Era `h3` fijo, y en una lista vacía va justo
  # debajo del `h1` de PageHeaderComponent: el lector de pantalla salta del
  # 1 al 3. Por defecto `h2`; adentro de una sección que ya tiene `h2`,
  # pasale `:h3`.
  def initialize(title:, description: nil, icon: "inbox", titulo_tag: :h2)
    @title = title
    @description = description
    @icon = icon
    @titulo_tag = titulo_tag
  end
end
