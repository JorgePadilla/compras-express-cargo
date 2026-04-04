# Database Diagram — Compras Express Cargo

> Auto-generated from `db/schema.rb` (version `2026_03_31_051755`)

```mermaid
erDiagram
    users {
        bigint id PK
        string email_address UK "not null"
        string password_digest "not null"
        string nombre "not null, default ''"
        string rol "not null, default 'digitador_miami'"
        string ubicacion "default 'honduras'"
        boolean activo "not null, default true"
        datetime created_at
        datetime updated_at
    }

    sessions {
        bigint id PK
        bigint user_id FK "not null"
        string ip_address
        string user_agent
        datetime created_at
        datetime updated_at
    }

    clientes {
        bigint id PK
        string codigo UK "not null"
        string nombre "not null"
        string apellido
        string identidad
        string email
        string telefono
        string telefono_whatsapp
        text direccion
        string ciudad
        string departamento
        decimal saldo_pendiente "default 0.0"
        bigint categoria_precio_id FK
        boolean correo_enviado "default false"
        boolean correo_confirmado "default false"
        boolean activo "default true"
        datetime created_at
        datetime updated_at
    }

    categoria_precios {
        bigint id PK
        string nombre "not null"
        decimal precio_libra_aereo "10,2"
        decimal precio_libra_maritimo "10,2"
        decimal precio_volumen "10,2"
        datetime created_at
        datetime updated_at
    }

    carriers {
        bigint id PK
        string nombre "not null"
        string tipo
        boolean activo "default true"
        datetime created_at
        datetime updated_at
    }

    tipo_envios {
        bigint id PK
        string nombre "not null"
        string codigo
        boolean activo "default true"
        datetime created_at
        datetime updated_at
    }

    consignatarios {
        bigint id PK
        string nombre "not null"
        string identidad
        text direccion
        datetime created_at
        datetime updated_at
    }

    empresa_manifiestos {
        bigint id PK
        string nombre "not null"
        boolean activo "default true"
        datetime created_at
        datetime updated_at
    }

    lugars {
        bigint id PK
        string nombre "not null"
        string tipo "bodega_miami, bodega_hn, punto_entrega"
        text direccion
        datetime created_at
        datetime updated_at
    }

    tamano_cajas {
        bigint id PK
        string nombre "not null"
        decimal largo "8,2"
        decimal ancho "8,2"
        decimal alto "8,2"
        datetime created_at
        datetime updated_at
    }

    configuracions {
        bigint id PK
        string clave UK "not null"
        text valor
        string tipo
        string categoria
        datetime created_at
        datetime updated_at
    }

    %% Relationships
    users ||--o{ sessions : "has_many"
    categoria_precios ||--o{ clientes : "has_many"
```

## Relationships

| Parent | Child | Type | FK | Notes |
|--------|-------|------|----|-------|
| `users` | `sessions` | 1:N | `user_id` | `dependent: :destroy` |
| `categoria_precios` | `clientes` | 1:N | `categoria_precio_id` | optional |

## Standalone Tables (no FK relationships yet)

These are catalog/lookup tables that will be referenced by future transactional tables (paquetes, manifiestos, facturas, etc.):

- **carriers** — shipping carriers (aereo, maritimo)
- **tipo_envios** — shipment types (AEREO, AEREO EXPRESS, MARITIMO)
- **consignatarios** — consignees for customs
- **empresa_manifiestos** — manifest companies
- **lugars** — warehouses and delivery points (enum: bodega_miami, bodega_hn, punto_entrega)
- **tamano_cajas** — box size presets (largo x ancho x alto)
- **configuracions** — key-value system settings

## User Roles

| Role | Description |
|------|-------------|
| `admin` | Full system access |
| `supervisor_miami` | Miami warehouse supervisor |
| `digitador_miami` | Miami data entry |
| `supervisor_caja` | Cashier supervisor |
| `supervisor_prefactura` | Pre-invoice supervisor |
| `cajero` | Cashier |
| `sac` | Customer service |
| `entrega_despacho` | Delivery/dispatch |
