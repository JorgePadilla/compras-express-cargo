# PR-D6.a: catálogos para automatizar cobros en pre-factura.
# Yusef confirmó (2026-05-01):
#  - Tarifa de recolecta por zona/distancia (no más $35 fijo).
#  - Catálogo de servicios extra (cambio de servicio, otros) con
#    costo + precio_venta + tipo de cobro USD|LPS, precio incluye ISV.
#  - Editable en pre-factura por descuentos autorizados.
#
# Este PR crea los catálogos. La integración con pre-factura
# (auto-agregar líneas de cobro al ingresar el paquete) va en PR-D6.b.
class CreateTarifasRecolectaYServiciosExtra < ActiveRecord::Migration[8.0]
  def change
    create_table :tarifas_recolecta do |t|
      t.string  :zona,    null: false
      t.decimal :monto,   null: false, precision: 10, scale: 2
      t.string  :moneda,  null: false, default: "USD" # usd | lps
      t.integer :position, null: false, default: 0
      t.boolean :activo,  null: false, default: true
      t.text    :notas
      t.timestamps
    end

    add_index :tarifas_recolecta, :zona
    add_index :tarifas_recolecta, :activo

    create_table :servicios_extra do |t|
      t.string  :codigo,        null: false
      t.string  :descripcion,   null: false
      t.decimal :costo,         null: false, precision: 10, scale: 2, default: 0
      t.decimal :precio_venta,  null: false, precision: 10, scale: 2
      t.string  :moneda,        null: false, default: "USD" # usd | lps
      t.boolean :precio_incluye_isv, null: false, default: true
      t.integer :position,      null: false, default: 0
      t.boolean :activo,        null: false, default: true
      t.text    :notas
      t.timestamps
    end

    add_index :servicios_extra, :codigo, unique: true
    add_index :servicios_extra, :activo
  end
end
