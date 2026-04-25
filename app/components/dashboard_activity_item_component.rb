class DashboardActivityItemComponent < ViewComponent::Base
  renders_one :badge

  def initialize(href:, avatar_name:, eyebrow:, title:, time: nil)
    @href = href
    @avatar_name = avatar_name
    @eyebrow = eyebrow
    @title = title
    @time = time
  end

  def avatar_class
    helpers.cliente_avatar_class(@avatar_name)
  end

  def initials
    helpers.cliente_initials(@avatar_name)
  end

  def relative_time
    return nil unless @time
    "hace #{helpers.time_ago_in_words(@time)}"
  end

  attr_reader :href, :eyebrow, :title
end
