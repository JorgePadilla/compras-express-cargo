# C33-05 · La «LÍNEA 2» de la dirección del casillero en Miami, que cambia por
# servicio: es lo que le dice a la bodega qué servicio pidió el cliente cuando
# el paquete llega a su nombre. Los valores son los de «Mis Direcciones» del
# sistema viejo (docs/05, «7. Mis Direcciones»), y se editan en /servicios.
#
# Va en la migración y no en seeds porque el deploy no siembra.
class AddLinea2CasilleroToTipoEnvios < ActiveRecord::Migration[8.0]
  LINEAS = {
    "cer" => "REEMPAQUE AEREO",
    "cka" => "AEREO CKA",
    "express" => "EXPRESS",
    "cem" => "REEMPAQUE MARITIMO",
    "ckm" => "MARITIMO CKM"
  }.freeze

  def up
    add_column :tipo_envios, :linea_2_casillero, :string
    LINEAS.each do |codigo, linea|
      execute "UPDATE tipo_envios SET linea_2_casillero = #{connection.quote(linea)} WHERE codigo = #{connection.quote(codigo)}"
    end
  end

  def down
    remove_column :tipo_envios, :linea_2_casillero
  end
end
