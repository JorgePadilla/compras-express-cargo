# C31-17 · PR-C31.9b · Cuántas etiquetas de entrega lleva la pre-factura.
#
# Yusef: *"igual también cuántas etiquetas el F9… igual que Miami cuando
# imprimimos paquetitos… es cuántos paquetes metimos en esa prefactura"*. El
# F9 de auditar lo pregunta, se guarda acá, y reimprimir (F4 en la ficha)
# saca las mismas. Vacía en las de antes: imprimen una, como hasta ahora.
class AddEtiquetasToPreFacturas < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_facturas, :etiquetas, :integer
    add_check_constraint :pre_facturas, "etiquetas IS NULL OR etiquetas BETWEEN 1 AND 99",
                         name: "pre_facturas_etiquetas_rango"
  end
end
