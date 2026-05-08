require "test_helper"

class PaquetesHelperTest < ActionView::TestCase
  include PaquetesHelper

  test "paquete_display_id returns numero_recepcion when present" do
    paquete = paquetes(:recibido)
    paquete.update_columns(numero_recepcion: "RM-2026-000123")
    assert_equal "RM-2026-000123", paquete_display_id(paquete)
  end

  test "paquete_display_id falls back to tracking when numero_recepcion blank" do
    paquete = paquetes(:recibido)
    paquete.update_columns(numero_recepcion: nil)
    assert_equal paquete.tracking, paquete_display_id(paquete)
  end

  test "paquete_display_id falls back to tracking when numero_recepcion empty string" do
    paquete = paquetes(:recibido)
    paquete.update_columns(numero_recepcion: "")
    assert_equal paquete.tracking, paquete_display_id(paquete)
  end

  test "paquete_display_id never returns guia (Yusef 2026-05-08)" do
    paquete = paquetes(:recibido)
    paquete.update_columns(numero_recepcion: nil)
    assert_not_equal paquete.guia, paquete_display_id(paquete)
  end
end
