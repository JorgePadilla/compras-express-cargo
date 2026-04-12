class AddEmailFlagsToVentas < ActiveRecord::Migration[8.0]
  def change
    add_column :ventas, :email_pendiente_enviado_at, :datetime
    add_column :ventas, :email_pagada_enviado_at,    :datetime
  end
end
