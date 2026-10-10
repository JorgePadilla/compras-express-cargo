require "test_helper"
require "invoicehn/test_support/contracts"

# PR-F1.2 · Los contratos que la gema `invoicehn` publica para que la app pruebe
# sus adaptadores (0.2.0, `invoicehn/test_support/contracts`). Corren contra
# Postgres de verdad: el punto `sps` (000-001) de las fixtures, su CAI ficticio
# 1–5000 y la Empresa de prueba, que tiene todo lo del Art. 10 num. 1.
module Fiscal
  module ConElPuntoDeSps
    def punto = puntos_de_emision(:sps)
    def contract_store = Fiscal::Store.new(punto: punto)
    def contract_sequence = Fiscal::Sequence.new
    def contract_ledger = Fiscal::Ledger.new
  end

  class StoreContractTest < ActiveSupport::TestCase
    include Invoicehn::TestSupport::StoreContract
    include ConElPuntoDeSps

    # Para que corra el de las notas (si no, se saltea): un CAI de notas de
    # crédito en el mismo punto.
    setup do
      AutorizacionSar.create!(punto_de_emision: punto, tipo_documento: "06", cai: "CAI-NOTAS-TEST",
                              rango_inicio: 1, rango_fin: 100, fecha_limite_emision: Fiscal.hoy + 30)
    end
  end

  class SequenceContractTest < ActiveSupport::TestCase
    include Invoicehn::TestSupport::SequenceContract
    include ConElPuntoDeSps
  end

  class LedgerContractTest < ActiveSupport::TestCase
    include Invoicehn::TestSupport::LedgerContract
    include ConElPuntoDeSps
  end

  class IssuanceContractTest < ActiveSupport::TestCase
    include Invoicehn::TestSupport::IssuanceContract
    include ConElPuntoDeSps
  end
end
