# RP-61 · El «No. Doc» no era un dato: era el ID de la caja con «DM» adelante.
#
# Se miró en el sistema viejo (`POST /Logistica/Manifiestos/GetManifiesto`,
# 196 manifiestos, 186 con cajas): `NoCajaPaquetes` vale **siempre**
# `"DM" + DetallesManifiestoID`, se pinta como `<td>` y no hay input. Nadie lo
# tecleó nunca. Su trabajo —identificar la caja en la etiqueta— acá lo hace
# `codigo`, que va bajo el QR y es lo que escanea Honduras.
#
# El campo de texto que `C21-04` le puso el 2026-09-05 era un input para algo
# que no se escribe. Se va con su columna.
class ElNoDocQueNadieTecleaba < ActiveRecord::Migration[8.0]
  def change
    remove_column :caja_manifiestos, :numero_doc, :string
  end
end
