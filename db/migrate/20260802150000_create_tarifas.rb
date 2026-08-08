# PR-10.a: el motor de precios. Hasta ahora el cobro salía de
# `cliente.categoria_precio.precio_para(tipo_envio) || tipo_envio.precio_libra`,
# que no sabe de mínimos, ni de escalones por peso, ni de excepciones — y
# además colapsa los 5 servicios en 2 modalidades (aéreo/marítimo), así que
# un cliente con categoría pagaba lo mismo en EXPRESS que en CER.
#
# Yusef (2026-08-02) describió cuatro mecanismos que hoy maneja a mano:
#   a) precio escalonado — "de una a tres libras vale tanto, de tres a tal
#      vale tanto"
#   b) precio especial por cliente Y servicio — "esa es la excepción que
#      arranca arriba de la tabla, pero solo en un servicio"
#   c) categorías/promos que anulan el mínimo — "en Chain solo es la libra o
#      la media libra... ahí es donde entran excepciones a las reglas"
#   d) cobro por media libra en esos casos
#
# Más: el mínimo varía por sucursal ("hay una pequeña diferencia de precio,
# costo extra de transporte") y por proveedor/promoción (Shein, Temu,
# doTERRA, Farmasi).
#
# Todo va en una sola tabla porque Jorge fijó el criterio en el audio:
# "mejor lo hacemos en esa tabla, que todo quede ahí registrado, porque
# cuando empezás a hacer muchas excepciones el sistema se complica".
class CreateTarifas < ActiveRecord::Migration[8.0]
  def change
    create_table :tarifas do |t|
      t.references :tipo_envio,       null: false, foreign_key: true
      t.references :categoria_precio,              foreign_key: true
      t.references :cliente,                       foreign_key: true
      t.references :sucursal,                      foreign_key: true
      t.references :proveedor,                     foreign_key: true

      # (a) escalón de peso. `hasta_libras` nil = sin tope superior.
      t.decimal :desde_libras, precision: 10, scale: 2, null: false, default: 0
      t.decimal :hasta_libras, precision: 10, scale: 2

      t.decimal :precio_libra, precision: 10, scale: 2, null: false
      t.string  :moneda,       null: false, default: "USD"

      # El mínimo se guarda SIN ISV. Yusef: "L.173.91 más ISV (queda en
      # L.200.00 ya con ISV)". El CRUD acepta el monto con ISV y convierte.
      t.decimal :minimo_monto,  precision: 10, scale: 2
      t.string  :minimo_moneda
      t.decimal :minimo_libras, precision: 10, scale: 2

      # (c) Exchange/Chain no aplica mínimo.
      t.boolean :aplica_minimo, null: false, default: true
      # (d) Granularidad del cobro. NULL = se cobra el peso tal cual, que es
      # el comportamiento actual del sistema — importante que sea el default,
      # porque cualquier valor acá redondea HACIA ARRIBA y cambiaría el monto
      # de todas las facturas existentes. 0.5 = media libra (Exchange/Chain),
      # 1.0 = libra entera.
      t.decimal :incremento_libras, precision: 4, scale: 2

      t.boolean :activo, null: false, default: true
      t.text    :notas

      t.timestamps
    end

    # Índices por eje de la cascada — cada nivel se resuelve con una query.
    add_index :tarifas, [ :cliente_id, :tipo_envio_id, :desde_libras ],
              name: "index_tarifas_por_cliente"
    add_index :tarifas, [ :proveedor_id, :tipo_envio_id, :desde_libras ],
              name: "index_tarifas_por_proveedor"
    add_index :tarifas, [ :categoria_precio_id, :tipo_envio_id, :desde_libras ],
              name: "index_tarifas_por_categoria"
    add_index :tarifas, [ :tipo_envio_id, :desde_libras ],
              name: "index_tarifas_por_servicio"

    reversible do |dir|
      dir.up do
        # Backfill: se preserva exactamente el comportamiento actual para que
        # ninguna factura cambie de monto al desplegar. Los mínimos quedan en
        # nil hasta que Yusef mande la tabla — sin mínimo, el cobro es el
        # mismo de siempre.
        execute <<~SQL
          INSERT INTO tarifas (tipo_envio_id, precio_libra, moneda, desde_libras,
                               aplica_minimo, activo, notas,
                               created_at, updated_at)
          SELECT id, COALESCE(precio_libra, 0), 'USD', 0,
                 true, true,
                 'Backfill PR-10.a desde tipo_envios.precio_libra',
                 NOW(), NOW()
            FROM tipo_envios
           WHERE activo = true AND precio_libra IS NOT NULL
        SQL

        # Las 3 categorías existentes replicadas por servicio según su
        # modalidad — que es justamente la limitación que esto viene a
        # resolver, pero hay que preservar lo que se cobra hoy.
        execute <<~SQL
          INSERT INTO tarifas (tipo_envio_id, categoria_precio_id, precio_libra, moneda,
                               desde_libras, aplica_minimo, activo, notas,
                               created_at, updated_at)
          SELECT te.id, cp.id,
                 CASE te.modalidad
                   WHEN 'maritimo' THEN cp.precio_libra_maritimo
                   ELSE cp.precio_libra_aereo
                 END,
                 'USD', 0, true, true,
                 'Backfill PR-10.a desde categoria_precios (por modalidad)',
                 NOW(), NOW()
            FROM tipo_envios te
            CROSS JOIN categoria_precios cp
           WHERE te.activo = true
             AND CASE te.modalidad
                   WHEN 'maritimo' THEN cp.precio_libra_maritimo
                   ELSE cp.precio_libra_aereo
                 END IS NOT NULL
        SQL
      end
    end
  end
end
