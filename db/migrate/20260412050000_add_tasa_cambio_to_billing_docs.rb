class AddTasaCambioToBillingDocs < ActiveRecord::Migration[8.0]
  def change
    %i[pre_facturas ventas notas_debito notas_credito pagos recibos].each do |table|
      add_column table, :tasa_cambio_aplicada, :decimal, precision: 10, scale: 4
    end
  end
end
