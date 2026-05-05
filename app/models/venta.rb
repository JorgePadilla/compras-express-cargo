# DEPRECATED — usar `Factura` directamente.
#
# La clase `Venta` se renombró a `Factura` en PR-FAC.2 (consolidación
# Venta+PreFactura). Este shim hace `Venta` un alias real de `Factura` (no
# subclase). Mantiene `Venta.foo`, `belongs_to :venta, class_name: "Factura"`,
# `@venta = Venta.find` y todas las referencias legacy funcionando hasta que
# PR-3 las migre. PR-4 borrará este archivo.
Venta = Factura
