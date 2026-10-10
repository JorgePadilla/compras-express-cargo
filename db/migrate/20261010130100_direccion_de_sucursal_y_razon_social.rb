# PR-F1.1 · Lo que la factura SAR pide del emisor y hoy no está guardado.
#
# - `sucursales.direccion`: el Art. 10 num. 2 pide la dirección del
#   establecimiento que emite, y la factura sale de la sucursal de quien factura
#   (decisión 4 de Jorge, 2026-10-10). La de la empresa es la casa matriz.
# - `empresas.razon_social`: el nombre legal del obligado tributario (num. 1),
#   que no tiene por qué ser el comercial que hoy está en `nombre`.
#
# Nullable las dos: se cargan por pantalla en F1.4, y la emisión (F1.2) se
# niega si falta alguna.
class DireccionDeSucursalYRazonSocial < ActiveRecord::Migration[8.0]
  def change
    add_column :sucursales, :direccion, :text
    add_column :empresas, :razon_social, :string
  end
end
