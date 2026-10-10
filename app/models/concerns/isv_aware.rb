# PR-10.a: fuente única de la tasa de ISV.
#
# Antes vivía duplicada como constante `ISV_RATE = 0.15` en cinco modelos
# (PreFactura, Venta, Cotizacion, NotaDebito, NotaCredito), mientras
# `empresas.isv_rate` — que SÍ es editable por un admin desde /empresas/edit —
# solo se usaba para imprimir la etiqueta "ISV (15%)" en los PDFs.
#
# El resultado era que si alguien cambiaba la tasa a 18%, el PDF decía 18% y
# el cálculo seguía aplicando 15%. Ahora ambos leen lo mismo.
#
# PR-F2.1 · Fase 15 (D4 de FISCAL.md): la tasa deja de leerse de `empresas` y
# sale de la gema — `Invoicehn::TaxTreatment::GRAVADO_15`, la tarifa general
# del Decreto 278-2013 Art. 16. Es la misma que aplica `Fiscal::Totales`, así
# que la etiqueta «ISV (15%)» y el cálculo no pueden volver a separarse. La
# columna `empresas.isv_rate` queda, pero `Empresa` solo acepta ese valor (la
# leen todavía `Tarifa`, `/tasa_cambio` y el PDF). El 18 % y los exentos van
# por línea en F3 (`TratamientoFiscal`), no cambiando esta tasa.
module IsvAware
  extend ActiveSupport::Concern

  def self.rate
    Invoicehn::TaxTreatment::GRAVADO_15.rate
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
