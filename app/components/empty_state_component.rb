class EmptyStateComponent < ViewComponent::Base
  renders_one :action

  def initialize(title:, description: nil, icon: "inbox")
    @title = title
    @description = description
    @icon = icon
  end
end
