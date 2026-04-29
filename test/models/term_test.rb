require "test_helper"

class TermTest < ActiveSupport::TestCase
  test "valid con todos los campos requeridos" do
    term = Term.new(
      version: "2026-01", language: "es", body: "Cuerpo",
      effective_from: Date.current
    )
    assert term.valid?
  end

  test "valida combinación version+language única" do
    Term.create!(version: "2026-01", language: "es", body: "x", effective_from: Date.current)
    duplicate = Term.new(version: "2026-01", language: "es", body: "y", effective_from: Date.current)
    assert_not duplicate.valid?
  end

  test "permite misma version en otro language" do
    Term.create!(version: "2026-01", language: "es", body: "x", effective_from: Date.current)
    en = Term.new(version: "2026-01", language: "en", body: "y", effective_from: Date.current)
    assert en.valid?
  end

  test "language debe ser es o en" do
    term = Term.new(version: "2026-01", language: "fr", body: "x", effective_from: Date.current)
    assert_not term.valid?
  end

  test "body_for devuelve el cuerpo de la version+language pedidos" do
    Term.create!(version: "2026-02", language: "es", body: "Cuerpo ES",
                 effective_from: Date.current)
    assert_equal "Cuerpo ES", Term.body_for(version: "2026-02", language: "es")
  end

  test "body_for cae a la version activa más reciente cuando no encuentra" do
    Term.create!(version: "2025-01", language: "es", body: "Viejo",
                 effective_from: Date.new(2025, 1, 1))
    Term.create!(version: "2025-06", language: "es", body: "Reciente",
                 effective_from: Date.new(2025, 6, 1))
    # version inexistente cae al más reciente
    assert_equal "Reciente", Term.body_for(version: "9999-99", language: "es")
  end

  test "current_version devuelve la version más reciente activa" do
    Term.create!(version: "2025-01", language: "es", body: "x", effective_from: Date.new(2025, 1, 1))
    Term.create!(version: "2026-01", language: "es", body: "y", effective_from: Date.new(2026, 1, 1))
    assert_equal "2026-01", Term.current_version
  end
end
