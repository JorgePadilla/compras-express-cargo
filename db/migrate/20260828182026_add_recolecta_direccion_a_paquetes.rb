class AddRecolectaDireccionAPaquetes < ActiveRecord::Migration[8.0]
  # C19-03. Yusef: "lo único que hace falta es que pongamos un campo que diga
  # dirección. Dirección de la recolecta". Hoy la dirección se cuela en
  # `recolecta_instrucciones` — el placeholder mismo decía "Dónde queda…".
  def change
    add_column :paquetes, :recolecta_direccion, :text
  end
end
