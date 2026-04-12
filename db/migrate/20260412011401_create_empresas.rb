class CreateEmpresas < ActiveRecord::Migration[8.0]
  def change
    create_table :empresas do |t|
      t.string  :nombre, null: false, default: "Compras Express Cargo"
      t.string  :rtn
      t.string  :telefono
      t.string  :email_contacto
      t.text    :direccion
      t.string  :ciudad, default: "San Pedro Sula"
      t.string  :pais, default: "Honduras"
      t.string  :moneda_default, default: "LPS"
      t.decimal :isv_rate, precision: 5, scale: 4, default: 0.15
      t.string  :sitio_web
      t.text    :terminos_factura

      t.timestamps
    end
  end
end
