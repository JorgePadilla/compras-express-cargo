class StepperComponent < ViewComponent::Base
  # steps: Array of { label: String, status: :upcoming | :active | :completed }
  def initialize(steps:)
    @steps = steps
  end

  private

  attr_reader :steps

  def circle_classes(status)
    case status
    when :active
      "border-cec-gold bg-cec-gold text-white shadow-lg ring-4 ring-cec-gold/20"
    when :completed
      "border-cec-teal bg-cec-teal text-white"
    else
      "border-gray-300 bg-white text-gray-400"
    end
  end

  def connector_classes(next_status)
    # The connector between step i and step i+1 is filled when the later step is active or completed
    if %i[active completed].include?(next_status)
      "bg-cec-teal"
    else
      "bg-gray-200"
    end
  end

  def label_classes(status)
    case status
    when :active
      "text-cec-navy font-semibold"
    when :completed
      "text-cec-teal font-medium"
    else
      "text-gray-400 font-medium"
    end
  end
end
