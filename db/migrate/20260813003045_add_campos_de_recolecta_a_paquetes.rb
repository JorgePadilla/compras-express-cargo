class AddCamposDeRecolectaAPaquetes < ActiveRecord::Migration[8.0]
  # A7-23. Lo que le falta al motorista para ir a traer la carga, dicho por
  # Yusef con un caso real:
  #
  #   > "Hay unos campos que hay que agregar, que es **horarios**… horarios y la
  #   >  persona encargada con número, información."
  #   > "El paquete de Jorge Padilla me dijeron que **preguntara por Manuel
  #   >  Quiñones**, el número de teléfono es tal, el horario de la empresa
  #   >  trabajan de 9 a 6."
  #
  # Sin esto la recolecta se coordina por WhatsApp aparte del sistema, que es
  # exactamente lo que hace que un motorista llegue a una bodega cerrada.
  #
  # `recolecta_instrucciones` es texto libre a propósito: el precedente es
  # `pre_alerta_paquetes.instrucciones`, que también lo es y funciona.
  def change
    add_column :paquetes, :recolecta_horario,       :string
    add_column :paquetes, :recolecta_contacto,      :string
    add_column :paquetes, :recolecta_telefono,      :string
    add_column :paquetes, :recolecta_instrucciones, :text
  end
end
