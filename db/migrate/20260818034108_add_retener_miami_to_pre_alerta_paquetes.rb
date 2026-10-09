# Marcar desde la pre-alerta que el paquete llega retenido.
#
# Yusef: *"nos hace falta la opción de Retener en Miami en Pre Alerta de
# Admin"*. Hoy la retención solo se puede marcar al etiquetar, o sea cuando el
# paquete ya está en el mostrador — y a veces se sabe antes.
#
# Va la bandera, sin motivos. En `/etiquetar` la retención lleva
# `motivo_retencion_ids`, y arrastrar eso desde la pre-alerta pide otra tabla de
# join. El motivo se sabe cuando el paquete llega, que es donde ya se pide.
class AddRetenerMiamiToPreAlertaPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_column :pre_alerta_paquetes, :retener_miami, :boolean, null: false, default: false
  end
end
