require "test_helper"

# PR-F1.1 · Solo reporta: encuentra los RTN viejos fuera de formato y no
# cambia nada.
class Fiscal::RtnInvalidosTest < ActiveSupport::TestCase
  test "separa los que se arreglan al guardar de los que hay que corregir" do
    # SQL directo: `update_column` también pasa por `normalizes`, y acá se
    # simula lo que quedó guardado cuando el RTN era texto libre.
    guardar_tal_cual(clientes(:juan), "0801-1998-123456")
    guardar_tal_cual(clientes(:maria), "12345")
    guardar_tal_cual(empresas(:singleton), "N/A")

    hallazgos = Fiscal::RtnInvalidos.detectar.index_by { |h| [ h.modelo, h.id ] }

    assert_equal :se_arregla_al_guardar, hallazgos[[ "Cliente", clientes(:juan).id ]].motivo
    assert_equal :invalido, hallazgos[[ "Cliente", clientes(:maria).id ]].motivo
    assert_equal :invalido, hallazgos[[ "Empresa", empresas(:singleton).id ]].motivo
    assert_equal 3, hallazgos.size

    assert_equal "12345", clientes(:maria).reload.rtn, "no reescribe nada"
  end

  test "los de 14 dígitos y los vacíos no salen" do
    guardar_tal_cual(clientes(:juan), "")
    guardar_tal_cual(clientes(:maria), "08011998123456")
    assert_empty Fiscal::RtnInvalidos.detectar
  end

  private

  def guardar_tal_cual(registro, rtn)
    registro.class.connection.exec_update(
      "UPDATE #{registro.class.table_name} SET rtn = $1 WHERE id = $2", "rtn", [ rtn, registro.id ]
    )
  end
end
