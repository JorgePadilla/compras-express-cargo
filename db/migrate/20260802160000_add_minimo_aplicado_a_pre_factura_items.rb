# PR-10.a: `PreFacturaItem#calculate_subtotal_from_peso` recalcula
# `subtotal = peso_cobrar × precio_libra` en cada validación, para que el
# cajero pueda editar peso o precio en el form y ver el monto actualizado.
#
# Eso pisa dos casos legítimos donde el subtotal NO sale de esa multiplicación:
#   1. El cobro mínimo de servicio (peso × precio queda por debajo del piso).
#   2. El cobro simbólico de prepagado en Miami.
#
# Esta bandera deja que el callback sepa cuándo no debe tocar el monto.
class AddMinimoAplicadoAPreFacturaItems < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_factura_items, :minimo_aplicado, :boolean, null: false, default: false
  end
end
