require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  include DashboardHelper

  # ── greeting_for ──

  test "greeting_for mañana" do
    assert_equal "Buenos días", greeting_for(Time.zone.local(2026, 4, 25, 9, 0, 0))
  end

  test "greeting_for tarde" do
    assert_equal "Buenas tardes", greeting_for(Time.zone.local(2026, 4, 25, 15, 0, 0))
  end

  test "greeting_for noche" do
    assert_equal "Buenas noches", greeting_for(Time.zone.local(2026, 4, 25, 22, 0, 0))
  end

  # ── compute_delta ──

  test "compute_delta calcula porcentaje positivo" do
    d = compute_delta(120, 100)
    assert_equal 20, d[:pct]
    assert_equal :up, d[:direction]
    assert_equal "+20%", d[:label_short]
  end

  test "compute_delta calcula porcentaje negativo" do
    d = compute_delta(80, 100)
    assert_equal(-20, d[:pct])
    assert_equal :down, d[:direction]
    assert_equal "-20%", d[:label_short]
  end

  test "compute_delta marca :new cuando ayer fue 0 y hoy > 0" do
    d = compute_delta(5, 0)
    assert_equal :new, d[:direction]
    assert_equal "nuevo", d[:label_short]
  end

  test "compute_delta marca :flat cuando ambos son 0" do
    d = compute_delta(0, 0)
    assert_equal :flat, d[:direction]
    assert_equal "—", d[:label_short]
  end

  # ── delta_chip_classes inverso ──

  test "delta_chip_classes inverse trata bajada como buena" do
    classes = delta_chip_classes(:down, inverse: true)
    assert_match(/cec-teal/, classes)
  end

  test "delta_chip_classes default trata subida como buena" do
    classes = delta_chip_classes(:up)
    assert_match(/cec-teal/, classes)
  end

  # ── avatar ──

  test "cliente_initials toma 2 iniciales por defecto" do
    assert_equal "JP", cliente_initials("Juan Perez")
    assert_equal "JC", cliente_initials("Juan Carlos Lopez")
  end

  test "cliente_initials con nombre vacío devuelve ?" do
    assert_equal "?", cliente_initials("")
    assert_equal "?", cliente_initials(nil)
  end

  test "cliente_avatar_class es determinístico" do
    assert_equal cliente_avatar_class("Juan Perez"), cliente_avatar_class("Juan Perez")
    assert_includes DashboardHelper::AVATAR_GRADIENTS, cliente_avatar_class("Maria Lopez")
  end

  # ── sparkline ──

  test "sparkline_points devuelve string de puntos x,y" do
    pts = sparkline_points([ 1, 2, 3 ], width: 30, height: 10, padding: 0)
    parts = pts.split(" ")
    assert_equal 3, parts.length
    parts.each { |p| assert_match(/\d+(\.\d+)?,\d+(\.\d+)?/, p) }
  end

  test "sparkline_points blank input" do
    assert_equal "", sparkline_points([])
  end

  # ── health_chip ──

  test "health_chip ok" do
    dot, chip, msg = health_chip(level: :ok, message: "Operación saludable")
    # 2026-05-02: rediseño — chip solid teal-dark con texto blanco;
    # dot teal-light para halo dentro de la familia teal.
    assert_match(/bg-cec-teal/, dot)
    assert_match(/bg-cec-teal-dark/, chip)
    assert_match(/text-white/, chip)
    assert_equal "Operación saludable", msg
  end

  test "health_chip alert" do
    dot, chip, msg = health_chip(level: :alert, message: "Crítico")
    assert_match(/bg-white/, dot)
    assert_match(/bg-red-/, chip)
    assert_match(/text-white/, chip)
    assert_equal "Crítico", msg
  end
end
