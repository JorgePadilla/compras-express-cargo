require "test_helper"

# PR-F1.2 · El emisor (Art. 10 num. 1) y el comprador (Art. 11), armados desde
# la Empresa, la sucursal del punto y el Cliente.
class Fiscal::EmisorTest < ActiveSupport::TestCase
  test "el emisor es la Empresa con la dirección de la sucursal del punto" do
    emisor = Fiscal::Emisor.para(puntos_de_emision(:tgu))

    assert_equal "08011998123456", emisor.rtn.to_s
    assert_equal "Razón social de prueba", emisor.legal_name
    assert_equal "Compras Express Cargo", emisor.trade_name
    assert_equal "Dirección de prueba, Tegucigalpa", emisor.branch_address
    assert emisor.branch?
    assert_empty emisor.missing_fields
  end

  test "fuera de la casa matriz, sin dirección de la sucursal falta un dato y no se emite" do
    sucursales(:humuya_tgu).update!(direccion: nil)
    emisor = Fiscal::Emisor.para(puntos_de_emision(:tgu))

    assert_includes emisor.missing_fields, Fiscal::Emisor::FALTA_LA_DIRECCION
    assert_not emisor.complete?
  end

  test "en la casa matriz, la dirección de la sucursal puede faltar: es la de la empresa" do
    sucursales(:zeron_sps).update!(direccion: nil)
    assert_empty Fiscal::Emisor.para(puntos_de_emision(:sps)).missing_fields
  end

  test "sin razón social falta un dato" do
    empresas(:singleton).update!(razon_social: nil)
    assert Fiscal::Emisor.para(puntos_de_emision(:sps)).missing_fields.any? { |f| f.include?("razón social") }
  end

  test "sin RTN válido no hay emisor" do
    Empresa.connection.execute("UPDATE empresas SET rtn = 'N/A'")
    assert_nil Fiscal::Emisor.para(puntos_de_emision(:sps))
  end

  test "con RTN es contribuyente; sin él, consumidor final con su identidad" do
    cliente = clientes(:juan)
    cliente.update_columns(rtn: "08011985123456", identidad: "0801198512345")
    contribuyente = Fiscal::ClienteFiscal.para(cliente)
    assert contribuyente.taxpayer?
    assert_equal "08011985123456", contribuyente.rtn.to_s
    assert_equal cliente.nombre_completo, contribuyente.name

    cliente.update_columns(rtn: nil)
    final = Fiscal::ClienteFiscal.para(cliente)
    assert final.consumidor_final?
    assert_equal "Identidad 0801198512345", final.identification_line

    cliente.update_columns(rtn: "0801-98-1", identidad: nil)
    assert Fiscal::ClienteFiscal.para(cliente).consumidor_final?, "un RTN fuera de formato no lo hace contribuyente"
  end

  test "el reloj de la gema es la fecha de Tegucigalpa" do
    travel_to Time.utc(2026, 10, 11, 3, 0, 0) do
      assert_equal Date.new(2026, 10, 10), Invoicehn.today
    end
  end
end
