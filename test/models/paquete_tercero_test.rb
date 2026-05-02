require "test_helper"

# PR-D3.c: tercero — cliente final cuando CEC le maneja la carga a otra
# empresa pequeña. Yusef pidió que se pueda cambiar via lupa.
class PaqueteTerceroTest < ActiveSupport::TestCase
  test "tercero is optional" do
    p = Paquete.new(tracking: "PT-TEST-NO-TERC", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert p.valid?
    assert_nil p.tercero
  end

  test "tercero apunta a un Cliente distinto del cliente principal" do
    juan = clientes(:juan)
    maria = clientes(:maria)
    p = Paquete.create!(tracking: "PT-TEST-TERC-#{SecureRandom.hex(3)}",
                        cliente: juan, tercero: maria, sucursal: sucursales(:miami))
    assert_equal maria, p.tercero
    assert_equal juan, p.cliente
    assert_not_equal p.cliente, p.tercero
  end

  test "borrar el cliente tercero pone tercero_id en null (on_delete: nullify)" do
    juan = clientes(:juan)
    cli_temporal = Cliente.create!(nombre: "Test", apellido: "Tercero",
                                    codigo: "CEC-TT#{SecureRandom.hex(2)}", email: "ttt#{SecureRandom.hex(2)}@x.com",
                                    activo: true)
    p = Paquete.create!(tracking: "PT-TEST-NULL-#{SecureRandom.hex(3)}",
                        cliente: juan, tercero: cli_temporal, sucursal: sucursales(:miami))
    cli_temporal.destroy
    p.reload
    assert_nil p.tercero
  end
end
