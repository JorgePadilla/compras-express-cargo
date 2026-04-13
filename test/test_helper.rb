ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Advance sequences past fixture data to avoid uniqueness conflicts
    parallelize_setup do
      %w[entregas_numero_seq aperturas_caja_numero_seq ingresos_caja_numero_seq egresos_caja_numero_seq].each do |seq|
        ActiveRecord::Base.connection.execute("SELECT setval('#{seq}', 100)")
      end
    end

    # Add more helper methods to be used by all tests here...
  end
end
