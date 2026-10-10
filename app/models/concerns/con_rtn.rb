# PR-F1.1 · El RTN de clientes y de la empresa, escrito una sola vez para los
# dos: es el mismo dato en la factura SAR (el del emisor y el del comprador), y
# dos copias de la regla se separan solas.
#
# - Se guarda sin guiones ni espacios (`0801-1998-123456` → `08011998123456`),
#   como lo normaliza `Invoicehn::Rtn`. El vacío del formulario queda `nil`.
# - Si está, son 14 dígitos. No es obligatorio: el consumidor final no lo da.
#
# Se valida **solo cuando cambia**. Lo que ya está en la base con otro formato
# (era texto libre) no traba un guardado que no toca el RTN —un pago, un cambio
# de teléfono—; para encontrarlo está `bin/rails fiscal:rtn_invalidos`, que
# solo reporta.
module ConRtn
  extend ActiveSupport::Concern

  included do
    normalizes :rtn, with: ->(rtn) { Fiscal.normalizar_rtn(rtn) }
    validates :rtn, format: { with: Fiscal::RTN, message: "debe tener 14 dígitos" },
                    allow_nil: true, if: :will_save_change_to_rtn?
  end
end
