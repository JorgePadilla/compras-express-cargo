class PageHeaderComponent < ViewComponent::Base
  renders_many :actions

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
