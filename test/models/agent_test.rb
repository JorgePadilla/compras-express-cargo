require "test_helper"

class AgentTest < ActiveSupport::TestCase
  test "valid with codigo and nombre" do
    agent = Agent.new(codigo: "215", nombre: "CORPORACION KARSAM")
    assert agent.valid?
  end

  test "codigo is required and unique case-insensitive" do
    Agent.create!(codigo: "K215", nombre: "X")
    duplicate = Agent.new(codigo: "k215", nombre: "Y")
    assert_not duplicate.valid?
  end

  test "destination_country defaults to Honduras" do
    agent = Agent.new(codigo: "A", nombre: "X")
    assert_equal "Honduras", agent.destination_country
  end

  test "scope activos excluye inactivos" do
    activo = Agent.create!(codigo: "A1", nombre: "A", activo: true)
    inactivo = Agent.create!(codigo: "A2", nombre: "B", activo: false)
    assert_includes Agent.activos, activo
    assert_not_includes Agent.activos, inactivo
  end

  test "to_s combina codigo y nombre" do
    agent = Agent.new(codigo: "215", nombre: "KARSAM")
    assert_equal "215 · KARSAM", agent.to_s
  end
end
