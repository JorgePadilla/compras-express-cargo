class PreFacturaPorManifiesto < ActiveRecord::Migration[8.0]
  # C21-10. Yusef se corrigió solo en la reunión del 2026-08-29: arrancó
  # diciendo que en la pre-factura va la guía y a los minutos volvió sobre
  # eso — *"está malo… porque no es la guía del proveedor, es el manifiesto"*.
  # Hoy el número lo tipean a mano: *"le ponen esa guía, se la ponen manual"*.
  #
  # Va nullable a propósito: una pre-factura de recolecta, o de un paquete
  # que entró por otra vía, no tiene manifiesto y sigue siendo válida.
  def change
    add_reference :pre_facturas, :manifiesto, foreign_key: true, null: true
  end
end
