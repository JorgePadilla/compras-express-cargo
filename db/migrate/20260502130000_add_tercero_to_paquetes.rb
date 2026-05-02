# PR-D3.c: tercero — cliente final cuando CEC le maneja la carga a otra
# empresa pequeña. Yusef (spec consolidada): "agregaremos un campo de
# 3ro (debe ir una lupa para poder cambiar a nombre de otro cliente o
# empresa)".
#
# El cliente_id principal sigue siendo el contratante (la empresa
# pequeña). El tercero_id es el destinatario final / cliente real
# de esa empresa pequeña.
class AddTerceroToPaquetes < ActiveRecord::Migration[8.0]
  def change
    add_reference :paquetes, :tercero,
                  null: true,
                  foreign_key: { to_table: :clientes, on_delete: :nullify }
  end
end
