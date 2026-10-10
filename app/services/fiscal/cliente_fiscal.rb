# PR-F1.2 · Fase 15. El comprador como lo pide el Art. 11 de la gema.
#
# Con RTN de 14 dígitos es contribuyente (`Taxpayer`, num. 1: para crédito
# fiscal); sin él, consumidor final (num. 2) con su nombre y, si la tiene, su
# identidad. Un RTN guardado fuera de formato (era texto libre hasta F1.1) no
# lo vuelve contribuyente: sale consumidor final, y `fiscal:rtn_invalidos` lo
# lista para corregirlo.
module Fiscal
  module ClienteFiscal
    def self.para(cliente)
      nombre = cliente.nombre_completo
      rtn = Fiscal.normalizar_rtn(cliente.rtn)
      return Invoicehn::Customer::Taxpayer.new(name: nombre, rtn: rtn) if rtn&.match?(Fiscal::RTN)

      identidad = cliente.identidad.to_s.strip.presence
      Invoicehn::Customer::ConsumidorFinal.new(name: nombre, identification_type: ("Identidad" if identidad),
                                               identification_number: identidad)
    end
  end
end
