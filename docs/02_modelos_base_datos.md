# Compras Express Cargo - Modelos y Base de Datos

## Diagrama de Relaciones

```
User (empleados)
 ├── has_many :ventas
 ├── has_many :entregas
 └── has_many :manifiestos (created_by)

Cliente
 ├── has_many :paquetes
 ├── has_many :ventas
 ├── has_many :recibos
 ├── has_many :pagos
 ├── has_many :pre_alertas
 ├── belongs_to :categoria_precio
 └── has_many :notas_credito

Paquete
 ├── belongs_to :cliente
 ├── belongs_to :manifiesto (optional)
 ├── belongs_to :pre_alerta (optional)
 ├── has_one :pre_factura
 ├── has_one :venta_item
 └── belongs_to :tipo_envio

Manifiesto
 ├── has_many :paquetes
 ├── belongs_to :empresa_manifiesto
 ├── belongs_to :carrier
 ├── belongs_to :consignatario
 └── belongs_to :user (created_by)

Venta
 ├── belongs_to :cliente
 ├── belongs_to :user
 ├── has_many :venta_items
 ├── has_many :paquetes, through: :venta_items
 ├── has_one :recibo
 └── has_one :pago

Pago
 ├── belongs_to :venta
 └── belongs_to :cliente
```

---

## Migraciones

### users (Empleados del sistema)
```ruby
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :nombre, null: false
      t.string :email_address, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.string :rol, default: "empleado"  # admin, empleado, cajero, bodega
      t.boolean :activo, default: true

      t.timestamps
    end
  end
end
```

### clientes
```ruby
class CreateClientes < ActiveRecord::Migration[8.0]
  def change
    create_table :clientes do |t|
      t.string :codigo, null: false, index: { unique: true }  # CEC-001, etc.
      t.string :nombre, null: false
      t.string :apellido
      t.string :identidad                    # Documento de identidad
      t.string :email
      t.string :telefono
      t.string :telefono_whatsapp
      t.text :direccion
      t.string :ciudad
      t.string :departamento                 # Estado/departamento Honduras
      t.decimal :saldo_pendiente, precision: 10, scale: 2, default: 0
      t.references :categoria_precio, foreign_key: true
      t.boolean :correo_enviado, default: false     # C.E.
      t.boolean :correo_confirmado, default: false  # C.C.
      t.boolean :activo, default: true

      t.timestamps
    end
  end
end
```

### paquetes
```ruby
class CreatePaquetes < ActiveRecord::Migration[8.0]
  def change
    create_table :paquetes do |t|
      t.string :tracking, null: false, index: true
      t.string :guia                          # Número de guía
      t.references :cliente, null: false, foreign_key: true
      t.references :manifiesto, foreign_key: true
      t.references :tipo_envio, foreign_key: true
      t.string :estado, default: "recibido"
        # recibido, etiquetado, en_manifiesto, enviado,
        # en_aduana, en_bodega_hn, pre_facturado, facturado, entregado, anulado
      t.decimal :peso, precision: 10, scale: 2
      t.decimal :volumen, precision: 10, scale: 2
      t.decimal :precio_libra, precision: 10, scale: 2
      t.decimal :monto_total, precision: 10, scale: 2
      t.text :descripcion
      t.string :remitente
      t.boolean :pre_alerta, default: false
      t.boolean :pre_factura, default: false
      t.boolean :solicito_cambio_servicio, default: false  # Amarillo
      t.boolean :retener_miami, default: false              # Azul
      t.datetime :fecha_recibido_miami
      t.datetime :fecha_enviado
      t.datetime :fecha_llegada_hn

      t.timestamps
    end
  end
end
```

### manifiestos
```ruby
class CreateManifiestos < ActiveRecord::Migration[8.0]
  def change
    create_table :manifiestos do |t|
      t.string :numero, null: false, index: { unique: true }  # MA00001378
      t.string :numero_caja
      t.string :numero_guia
      t.references :empresa_manifiesto, foreign_key: true     # PRONTO CARGO, SERCARGO, etc.
      t.string :estado, default: "creado"                     # creado, enviado, en_aduana, recibido
      t.string :tipo_envio                                    # AEREO, AEREO EXPRESS, CKM MARITIMO, CKA ESTANDARD
      t.string :expedido_por
      t.integer :cantidad_paquetes, default: 0
      t.decimal :volumen_total, precision: 10, scale: 2, default: 0
      t.decimal :peso_total, precision: 10, scale: 2, default: 0
      t.datetime :fecha_enviado
      t.datetime :fecha_aduana
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
```

### ventas
```ruby
class CreateVentas < ActiveRecord::Migration[8.0]
  def change
    create_table :ventas do |t|
      t.string :numero, null: false, index: { unique: true }
      t.references :cliente, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :impuesto, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.string :estado, default: "pendiente"  # pendiente, pagada, anulada
      t.decimal :saldo_pendiente, precision: 10, scale: 2, default: 0
      t.string :moneda, default: "LPS"        # LPS o USD

      t.timestamps
    end
  end
end
```

### pagos
```ruby
class CreatePagos < ActiveRecord::Migration[8.0]
  def change
    create_table :pagos do |t|
      t.references :venta, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string :moneda, default: "usd"
      t.string :estado, default: "pendiente"  # pendiente, completado, fallido, reembolsado
      t.string :metodo_pago                   # efectivo, tarjeta, transferencia
      t.datetime :pagado_at
      t.text :notas

      t.timestamps
    end
  end
end
```

### recibos
```ruby
class CreateRecibos < ActiveRecord::Migration[8.0]
  def change
    create_table :recibos do |t|
      t.string :numero, null: false, index: { unique: true }
      t.references :venta, null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.decimal :monto, precision: 10, scale: 2, null: false
      t.string :forma_pago                    # efectivo, tarjeta, transferencia
      t.text :notas

      t.timestamps
    end
  end
end
```

### entregas
```ruby
class CreateEntregas < ActiveRecord::Migration[8.0]
  def change
    create_table :entregas do |t|
      t.references :paquete, null: false, foreign_key: true
      t.references :cliente, null: false, foreign_key: true
      t.references :user, foreign_key: true   # Quién entregó
      t.datetime :fecha_entrega, null: false
      t.string :recibido_por                  # Nombre de quien recibe
      t.string :identidad_recibe              # DPI/identidad de quien recibe
      t.text :notas

      t.timestamps
    end
  end
end
```

### Tablas de configuración
```ruby
# categorias_precio
create_table :categorias_precio do |t|
  t.string :nombre, null: false
  t.decimal :precio_libra_aereo, precision: 10, scale: 2
  t.decimal :precio_libra_maritimo, precision: 10, scale: 2
  t.decimal :precio_volumen, precision: 10, scale: 2
  t.timestamps
end

# carriers
create_table :carriers do |t|
  t.string :nombre, null: false
  t.string :tipo          # aéreo, marítimo
  t.boolean :activo, default: true
  t.timestamps
end

# tipos_envio
create_table :tipos_envio do |t|
  t.string :nombre, null: false   # AEREO, AEREO EXPRESS, CKM MARITIMO, CKA ESTANDARD
  t.string :codigo
  t.boolean :activo, default: true
  t.timestamps
end

# empresas_manifiesto
create_table :empresas_manifiesto do |t|
  t.string :nombre, null: false   # PRONTO CARGO, SERCARGO, GENESIS
  t.boolean :activo, default: true
  t.timestamps
end

# consignatarios
create_table :consignatarios do |t|
  t.string :nombre, null: false
  t.string :identidad
  t.text :direccion
  t.timestamps
end

# lugares
create_table :lugares do |t|
  t.string :nombre, null: false
  t.string :tipo          # bodega_miami, bodega_hn, punto_entrega
  t.text :direccion
  t.timestamps
end

# tamanos_caja
create_table :tamanos_caja do |t|
  t.string :nombre, null: false
  t.decimal :largo, precision: 8, scale: 2
  t.decimal :ancho, precision: 8, scale: 2
  t.decimal :alto, precision: 8, scale: 2
  t.timestamps
end

# notas_credito
create_table :notas_credito do |t|
  t.references :cliente, null: false, foreign_key: true
  t.references :venta, foreign_key: true
  t.string :motivo
  t.decimal :monto, precision: 10, scale: 2
  t.timestamps
end

# configuraciones (key-value para settings del sistema)
create_table :configuraciones do |t|
  t.string :clave, null: false, index: { unique: true }
  t.text :valor
  t.string :tipo       # string, decimal, boolean, json
  t.string :categoria  # general, logistica, facturacion, marketing
  t.timestamps
end
```

---

## Seeds Iniciales (db/seeds.rb)

```ruby
# Tasa de cambio
Configuracion.create!(clave: "tasa_cambio", valor: "24.85", tipo: "decimal", categoria: "general")

# Tipos de envío (del sistema actual)
["AEREO", "AEREO EXPRESS", "CKM MARITIMO", "CKA ESTANDARD"].each do |tipo|
  TipoEnvio.create!(nombre: tipo, codigo: tipo.parameterize)
end

# Empresas de manifiesto
["PRONTO CARGO", "SERCARGO", "GENESIS"].each do |emp|
  EmpresaManifiesto.create!(nombre: emp)
end

# Usuario admin
User.create!(
  nombre: "Admin",
  email_address: "admin@comprasexpresscargo.com",
  password: "changeme123",
  rol: "admin"
)
```
