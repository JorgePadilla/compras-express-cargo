# PR-F2.1 · Cómo trata el ISV a una línea de cobro (Acuerdo 481-2017 Art. 11
# num. 1 lit. g-i: exento, exonerado, gravado 0 %, 15 %, 18 %). Lo lee
# `Fiscal::Totales` para armar la línea de la gema.
#
# Hoy todo lo que cobra la empresa es gravado al 15 %, que es lo que la fórmula
# de antes aplicaba a todas las líneas. Es la costura para F3 (tratamiento por
# servicio, exonerados, 18 %; Q1/Q2 de FISCAL.md, abiertas): cuando se decida,
# cambia este método y no los cinco `calculate_totals`.
module TratamientoFiscal
  extend ActiveSupport::Concern

  def tratamiento_fiscal
    :gravado_15
  end
end
