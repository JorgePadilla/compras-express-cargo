require "test_helper"
require Rails.root.join("db/migrate/20261011140000_quitar_leyenda_falsa_de_la_factura").to_s

# PR-F1.4 · La migración que saca «Esta factura es valida como comprobante
# fiscal» del pie de las facturas, en todos los entornos.
class LeyendaFalsaDeLaFacturaTest < ActiveSupport::TestCase
  def migrar = ActiveRecord::Migration.suppress_messages { QuitarLeyendaFalsaDeLaFactura.new.up }

  def pie(texto)
    Empresa.connection.exec_update("UPDATE empresas SET terminos_factura = $1", "pie", [ texto ])
  end

  test "saca solo la leyenda, con o sin tilde, y deja lo que la seguía" do
    { "Esta factura es valida como comprobante fiscal. Gracias por preferir Compras Express Cargo." =>
        "Gracias por preferir Compras Express Cargo.",
      "Esta factura es válida como comprobante fiscal." => nil,
      "ESTA FACTURA ES VALIDA COMO COMPROBANTE FISCAL" => nil }.each do |texto, queda|
      pie(texto)
      migrar
      quedo = empresas(:singleton).reload.terminos_factura
      queda.nil? ? assert_nil(quedo, texto) : assert_equal(queda, quedo, texto)
    end
  end

  test "un pie escrito a mano se respeta" do
    pie("Gracias por su compra. Esta factura es valida como comprobante fiscal.")
    migrar
    assert_equal "Gracias por su compra. Esta factura es valida como comprobante fiscal.",
                 empresas(:singleton).reload.terminos_factura
  end

  test "los seeds y las fixtures ya no la traen" do
    assert_no_match(/comprobante fiscal/i, File.read(Rails.root.join("db/seeds.rb")).lines.grep(/terminos_factura/).join)
    assert_no_match(/comprobante fiscal/i, empresas(:singleton).terminos_factura.to_s)
  end
end
