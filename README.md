# Compras Express Cargo (CEC)

Sistema de gestion integral para courier y paqueteria internacional (Miami → Honduras).

Reemplaza el sistema legacy ASP.NET MVC + DevExpress con una aplicacion moderna en Rails 8.

## Stack

- **Backend:** Ruby 3.3.9 / Rails 8 / PostgreSQL 17
- **Frontend:** Hotwire (Turbo + Stimulus) / Tailwind CSS 4 / ViewComponents
- **Jobs:** Solid Queue
- **PDFs:** Prawn
- **Deploy:** Render.com (staging + production)
- **CI/CD:** GitHub Actions

## Flujo principal

```
Pre-alerta → Recepcion Miami → Manifiesto → Pre-factura → Factura → Pago → Entrega
```

## Modulos implementados

| Fase | Descripcion | Estado |
|------|-------------|--------|
| 0 | Fundacion (auth, roles, layout, deploy) | ✅ |
| 1 | Miami (etiquetar paquetes, manifiestos) | ✅ |
| 2 | Pre-Alertas (wizard cliente + admin CRUD + auto-linking) | ✅ |
| 3a | Billing MVP (pre-factura → venta → pago → recibo) | ✅ |
| 3b | Notas D/C + PDFs + Emails | ✅ |
| 3c | Cotizaciones + Proformas + Financiamientos + Dual Currency | ✅ |
| 4 | Entregas + Caja Diaria | ✅ |
| 5 / 5b | Tareas + Re-empaque · Numeracion y Tracking | ✅ |
| 5c | Detalle de Paquete + Warehouse Receipt (serie `PR-D`) | 🔨 |
| 6 | Reportes + Configuraciones + Dashboard | 🔨 |
| 10 | Contexto operativo en captura (serie `PR-9`) | 🔨 |
| 11 | Tarifas y calculo de cobro (serie `PR-10`) | 🔨 |
| 12 | Escaneo de manifiesto + pre-etiqueta de caja | 📋 |
| 13 | Precio bloqueado + PIN de supervisor | ✅ |
| 7 / 8 / 9 | Marketing CRM · Inventario · Fotos de paquetes | 📋 |

El grueso del trabajo de agosto 2026 es la serie `PR-C6`, que sale de las
conversaciones con el cliente y **se sigue en `docs/05`**, no en la tabla de
fases. Ver [Series de PR](docs/06_fases_implementacion.md#series-de-pr).

**60 modelos, 116 migraciones, 7 mailers, 49 Stimulus controllers, 17 ViewComponents, 1879 tests.**

Ver detalle completo en [`docs/06_fases_implementacion.md`](docs/06_fases_implementacion.md)
y el indice de la documentacion en [`docs/README.md`](docs/README.md).

## Setup local

```bash
# Clonar e instalar dependencias
git clone git@github.com:JorgePadilla/compras-express-cargo.git
cd compras-express-cargo
bundle install

# Base de datos
bin/rails db:create db:schema:load db:seed

# Ejecutar
bin/dev
```

## Tests

```bash
bin/rails test
```

## Deploy

- **Staging:** push a `staging` branch → deploy automatico en Render
- **Production:** merge `staging` → `main` → deploy automatico en Render

## Documentacion

- [`docs/05_requerimientos_conversaciones.md`](docs/05_requerimientos_conversaciones.md) — Requerimientos del sistema
- [`docs/06_fases_implementacion.md`](docs/06_fases_implementacion.md) — Fases de implementacion y progreso
