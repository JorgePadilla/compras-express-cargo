# PR-F1.2 · Fase 15. El emisor de la factura (Art. 10 num. 1): la Empresa, con
# la dirección del establecimiento que emite, que es la de la sucursal del
# punto (decisión 4 de Jorge: la factura sale de la sucursal de quien factura).
#
# Es un `Invoicehn::Issuer` con un dato más. La gema, si la dirección del
# establecimiento viene vacía, pone la de la casa matriz: correcto para el
# establecimiento 000, **falso** para Humuya o San Manuel, que imprimirían la
# dirección de San Pedro sin que nadie lo note. Acá, fuera de la casa matriz,
# la dirección vacía es un dato faltante, y el validador de la gema se niega a
# emitir.
module Fiscal
  class Emisor < Invoicehn::Issuer
    CASA_MATRIZ = "000".freeze
    FALTA_LA_DIRECCION = "dirección del establecimiento del punto de emisión (Art. 10 num. 1 lit. d)".freeze

    # nil si la Empresa no tiene un RTN de 14 dígitos: para la gema es «no hay
    # emisor configurado», y no emite.
    def self.para(punto, empresa: Empresa.first)
      rtn = Fiscal.normalizar_rtn(empresa&.rtn)
      return nil unless rtn&.match?(Fiscal::RTN)

      new(rtn: rtn, legal_name: empresa.razon_social, trade_name: empresa.nombre,
          headquarters_address: empresa.direccion, branch_address: punto.sucursal.direccion,
          phone: empresa.telefono, email: empresa.email_contacto,
          casa_matriz: punto.establecimiento == CASA_MATRIZ)
    end

    # Antes de `super`: el Issuer se congela al final de su `initialize`.
    def initialize(casa_matriz: true, **datos)
      @sin_direccion_del_establecimiento = !casa_matriz && datos[:branch_address].to_s.strip.empty?
      super(**datos)
    end

    def missing_fields
      @sin_direccion_del_establecimiento ? (super + [ FALTA_LA_DIRECCION ]).uniq : super
    end
  end
end
