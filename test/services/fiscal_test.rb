require "test_helper"
require_relative "../support/con_app_host"

# PR-F1.1 · Lo que comparten los modelos fiscales (D7 de FISCAL.md).
class FiscalTest < ActiveSupport::TestCase
  include ConAppHost

  test "hoy es la fecha de Tegucigalpa, no la de UTC" do
    # 03:00 UTC del 11 son las 21:00 del 10 en Honduras.
    travel_to Time.utc(2026, 10, 11, 3, 0, 0) do
      assert_equal Date.new(2026, 10, 10), Fiscal.hoy
    end
  end

  test "producción es el host de producción, no RAILS_ENV" do
    en_produccion { assert Fiscal.produccion? }
    con_app_host("cec-staging.onrender.com") { assert_not Fiscal.produccion? }
    con_app_host(nil) { assert_not Fiscal.produccion? }
  end

  test "el RTN se normaliza sin guiones ni espacios, y el vacío queda nil" do
    assert_equal "08011998123456", Fiscal.normalizar_rtn("0801-1998-123456")
    assert_equal "08011998123456", Fiscal.normalizar_rtn(" 0801 1998 123456 ")
    assert_nil Fiscal.normalizar_rtn("")
    assert_nil Fiscal.normalizar_rtn(" - ")
  end
end
