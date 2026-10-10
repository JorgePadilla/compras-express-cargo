require "test_helper"

# PR-F1.1 · El RTN del comprador (Cliente) y del emisor (Empresa): una sola
# regla para los dos, en `ConRtn`.
class ConRtnTest < ActiveSupport::TestCase
  test "se guarda sin guiones ni espacios" do
    cliente = clientes(:juan)
    cliente.update!(rtn: "0801-1998-123456")
    assert_equal "08011998123456", cliente.reload.rtn

    empresa = empresas(:singleton)
    empresa.update!(rtn: " 0501 1990 654321 ")
    assert_equal "05011990654321", empresa.reload.rtn
  end

  test "el vacío del formulario queda nil y no es error" do
    cliente = clientes(:juan)
    assert cliente.update(rtn: "")
    assert_nil cliente.reload.rtn
  end

  test "si está, son 14 dígitos" do
    [ "123", "0801199812345", "080119981234567", "0801-1998-12345X" ].each do |malo|
      [ clientes(:juan), empresas(:singleton) ].each do |registro|
        registro.rtn = malo
        assert_not registro.valid?, "#{registro.class} aceptó #{malo.inspect}"
        assert_includes registro.errors[:rtn], "debe tener 14 dígitos"
      end
    end
  end

  test "un RTN viejo fuera de formato no traba un guardado que no lo toca" do
    cliente = clientes(:juan)
    # SQL directo: `update_column` también pasa por `normalizes`.
    Cliente.connection.execute("UPDATE clientes SET rtn = '0801-98-1' WHERE id = #{cliente.id}")
    assert cliente.reload.update(telefono: "33445566")
    assert_equal "0801-98-1", cliente.reload.rtn
  end

  test "la búsqueda por RTN también normaliza" do
    clientes(:juan).update!(rtn: "08011998123456")
    assert_equal clientes(:juan), Cliente.find_by(rtn: "0801-1998-123456")
  end
end
