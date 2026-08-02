# PR-D1.e: agregado por Yusef (2026-04-29):
# "muchos paquetes llegan con 2 numeros de seguimientos, necesitare poner
#  un campo de 2do Tracking (esto es porque el proveedor le da uno de los
#  2 y crean pre alerta y despues complica complirle al cliente)"
#
# Caso de uso: el proveedor le da al cliente UN tracking → cliente crea
# pre-alerta con ese tracking → el paquete físico llega con OTRO tracking
# → la vinculación PA ↔ paquete falla porque los strings no matchean.
#
# Solución: nueva columna nullable. Form de etiquetar acepta ambos.
# `PreAlertaPaquete.link_tracking!` matchea contra cualquiera.
# `Paquete::buscar` scope incluye el secundario en el ILIKE.
class AddTrackingSecundarioToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :tracking_secundario, :string
    add_index  :paquetes, :tracking_secundario
  end
end
