# C34-10 · Una nota permanente del cliente para quien pesa y mide. Yusef, en la
# pasada del 2026-10-30: *"si va a faltar aquí agregar ahora notas medición,
# porque ahora ya van a tener más tareas, entonces tienen que tener ciertas
# notas"*.
class AddNotasMedicionToClientes < ActiveRecord::Migration[8.0]
  def change
    add_column :clientes, :notas_medicion, :text
  end
end
