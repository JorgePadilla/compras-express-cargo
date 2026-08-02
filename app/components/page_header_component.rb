class PageHeaderComponent < ViewComponent::Base
  renders_many :actions
  renders_one  :meta

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end
end
