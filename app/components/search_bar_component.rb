class SearchBarComponent < ViewComponent::Base
  def initialize(url:, placeholder: "Buscar...", value: nil, param: :q)
    @url = url
    @placeholder = placeholder
    @value = value
    @param = param
  end
end
