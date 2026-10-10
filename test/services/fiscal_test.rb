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

  test "producción es todo servidor que no sea staging, no RAILS_ENV solo" do
    en_produccion { assert Fiscal.produccion? }
    en_staging { assert_not Fiscal.produccion? }
    # Desarrollo y tests no son producción, diga lo que diga APP_HOST.
    con_app_host(Fiscal::HOST_DE_PRODUCCION) { assert_not Fiscal.produccion? }
    con_app_host(nil) { assert_not Fiscal.produccion? }
  end

  # QA de PR-F1.1 · Falla cerrado. Producción contesta hoy en
  # cec-production.onrender.com, no en el dominio de render.yaml: un APP_HOST
  # que no es el del yaml no puede abrirle la puerta a la ficticia.
  test "un servidor con otro APP_HOST, o sin él, cuenta como producción" do
    en_servidor("cec-production.onrender.com") { assert Fiscal.produccion? }
    en_servidor(nil) { assert Fiscal.produccion? }
    en_servidor("CEC-STAGING.onrender.com") { assert Fiscal.produccion? }
  end

  test "el RTN se normaliza sin guiones ni espacios, y el vacío queda nil" do
    assert_equal "08011998123456", Fiscal.normalizar_rtn("0801-1998-123456")
    assert_equal "08011998123456", Fiscal.normalizar_rtn(" 0801 1998 123456 ")
    assert_nil Fiscal.normalizar_rtn("")
    assert_nil Fiscal.normalizar_rtn(" - ")
  end
end
