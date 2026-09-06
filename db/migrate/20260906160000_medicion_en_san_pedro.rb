# C26-02 · Medición: la estación de San Pedro donde cada caja recibida de Miami
# se pesa y se mide antes de la pre-factura. Yusef: *"¿cómo vamos a llamar a
# este módulo? Medición se llama"*.
#
# Dos sellos en el paquete —cuándo y quién lo midió— y dos en la pre-alerta,
# para la excepción de C26-03: facturar lo que hay aunque el grupo consolidado
# esté incompleto, autorizado con PIN de un jefe.
class MedicionEnSanPedro < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :medido_at, :datetime
    add_column :paquetes, :medido_por, :string
    add_column :pre_alertas, :union_parcial_at, :datetime
    add_column :pre_alertas, :union_parcial_por, :string
  end
end
