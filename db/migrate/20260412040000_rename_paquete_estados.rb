class RenamePaqueteEstados < ActiveRecord::Migration[8.0]
  def up
    # Merge en_manifiesto into enviado first (both become enviado_honduras)
    execute <<~SQL
      UPDATE paquetes SET estado = 'enviado_honduras' WHERE estado IN ('en_manifiesto', 'enviado');
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'recibido_miami' WHERE estado = 'recibido';
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'empacado' WHERE estado = 'etiquetado';
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'disponible_entrega' WHERE estado = 'en_bodega_hn';
    SQL

    change_column_default :paquetes, :estado, from: "recibido", to: "recibido_miami"
  end

  def down
    execute <<~SQL
      UPDATE paquetes SET estado = 'recibido' WHERE estado = 'recibido_miami';
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'etiquetado' WHERE estado = 'empacado';
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'enviado' WHERE estado = 'enviado_honduras';
    SQL

    execute <<~SQL
      UPDATE paquetes SET estado = 'en_bodega_hn' WHERE estado = 'disponible_entrega';
    SQL

    change_column_default :paquetes, :estado, from: "recibido_miami", to: "recibido"
  end
end
