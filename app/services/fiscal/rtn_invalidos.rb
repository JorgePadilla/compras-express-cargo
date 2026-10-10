# PR-F1.1 · Los RTN guardados que no son 14 dígitos, de clientes y empresa.
#
# Hasta F1.1 el RTN era texto libre. Desde ahí `ConRtn` lo normaliza y lo
# valida al guardar, pero lo que ya estaba no se reescribe: es dato real, y
# corregirlo es cosa de quien conoce al cliente. Esto solo lo encuentra, para
# que alguien lo arregle antes de facturar con él. Lo usa
# `bin/rails fiscal:rtn_invalidos`.
#
# Dos casos distintos:
# - `se_arregla_al_guardar`: con guiones o espacios, pero son 14 dígitos. El
#   próximo guardado del formulario lo deja bien.
# - `invalido`: ni sacándole guiones da 14 dígitos. Hay que corregirlo a mano;
#   el formulario no lo deja guardar así.
module Fiscal
  module RtnInvalidos
    Hallazgo = Data.define(:modelo, :id, :nombre, :rtn, :motivo)

    MODELOS = [ Cliente, Empresa ].freeze

    def self.detectar
      MODELOS.flat_map do |modelo|
        # SQL y no `where(rtn:)`: `normalizes` también reescribe los valores de
        # las consultas, y acá se busca lo que está guardado tal cual.
        modelo.where("rtn IS NOT NULL AND rtn <> '' AND rtn !~ '^[0-9]{14}$'")
              .order(:id).pluck(:id, :nombre, :rtn).map do |id, nombre, rtn|
          normalizado = Fiscal.normalizar_rtn(rtn)
          motivo = normalizado&.match?(Fiscal::RTN) ? :se_arregla_al_guardar : :invalido
          Hallazgo.new(modelo: modelo.name, id: id, nombre: nombre, rtn: rtn, motivo: motivo)
        end
      end
    end
  end
end
