# PR-10.a: fuente única de la tasa de ISV.
#
# Antes vivía duplicada como constante `ISV_RATE = 0.15` en cinco modelos
# (PreFactura, Venta, Cotizacion, NotaDebito, NotaCredito), mientras
# `empresas.isv_rate` — que SÍ es editable por un admin desde /empresas/edit —
# solo se usaba para imprimir la etiqueta "ISV (15%)" en los PDFs.
#
# El resultado era que si alguien cambiaba la tasa a 18%, el PDF decía 18% y
# el cálculo seguía aplicando 15%. Ahora ambos leen lo mismo.
module IsvAware
  extend ActiveSupport::Concern

  FALLBACK = BigDecimal("0.15")

  # La tasa vigente. Con fallback duro porque el cálculo de una factura no
  # puede quedarse sin tasa si la tabla `empresas` está vacía.
  def self.rate
    Empresa.instance.isv_rate&.to_d || FALLBACK
  rescue StandardError
    FALLBACK
  end

  def isv_rate
    IsvAware.rate
  end

  class_methods do
    def isv_rate
      IsvAware.rate
    end
  end
end
