# PR-9.c: "Revisar sonidos en Tegus" (Yusef, 2026-08-01). Además del fix del
# AudioContext suspendido, el volumen fijo en 0.3 con onda seno era muy poco
# para una bodega ruidosa. El operario ahora ajusta volumen y on/off desde el
# header de /etiquetar y /entrega_personal.
#
# Preferencia por USUARIO, siguiendo el precedente de `tema` y
# `sidebar_position` (20260503063133).
class AddSonidoPreferencesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sonido_habilitado, :boolean, null: false, default: true
    add_column :users, :sonido_volumen,    :integer, null: false, default: 60
  end
end
