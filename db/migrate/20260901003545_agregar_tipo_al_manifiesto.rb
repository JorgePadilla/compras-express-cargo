# `A7-07` · El **manifiesto interno de sucursal**.
#
# Yusef: *"es el de envío nacional, de una sucursal a la otra. Lleva un
# **manifiesto interno** y es igualito."* Igualito en comportamiento —se arma, se
# cierra, se recibe escaneando— pero no lleva nada de lo internacional: ni
# consignatario, ni empresa proveedora, ni guía, ni fecha de aduana.
#
# `oficial` por defecto para que todo lo que ya existe siga siendo lo que era.
class AgregarTipoAlManifiesto < ActiveRecord::Migration[8.0]
  def change
    add_column :manifiestos, :tipo, :string, null: false, default: "oficial"
    add_index  :manifiestos, :tipo
  end
end
