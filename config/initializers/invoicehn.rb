# PR-F1.2 · Fase 15. El reloj de la gema `invoicehn` es la fecha de Honduras.
#
# La gema fecha la emisión, la anulación y el chequeo de la fecha límite del
# CAI con `Invoicehn.today`, que por defecto es `Date.today` del **proceso**:
# en un servidor en UTC, de 18:00 a medianoche de Tegucigalpa sellaría la
# factura con la fecha de mañana. D7 de FISCAL.md: siempre `Fiscal.hoy`.
#
# El lambda se evalúa en cada emisión, así que `Fiscal` (autocargado) se
# resuelve recién ahí.
Invoicehn.configure { |c| c.today = -> { Fiscal.hoy } }
