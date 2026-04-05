# Staging Test Credentials

All users — admin staff and clientes — log in through the **same unified login** at
[`/session/new`](https://cec-staging.onrender.com/session/new). `SessionsController#create`
tries `User.authenticate_by` first and falls back to `Cliente.authenticate_by`, so the
app routes each user to the correct area automatically: admin users land on the admin
dashboard, clientes land on `/cuenta`.

## Admin users

| User | Email | Password | Role |
|:-----|:------|:---------|:-----|
| Administrador | admin@comprasexpresscargo.com | changeme123 | admin |
| Supervisor Miami | supervisor@cec.com | Demo123! | supervisor_miami |
| Digitador Miami | digitador@cec.com | Demo123! | digitador_miami |
| Supervisor Caja | sup_caja@cec.com | Demo123! | supervisor_caja |
| Cajero Honduras | cajero@cec.com | Demo123! | cajero |
| SAC | sac@cec.com | Demo123! | sac |
| Entrega | entrega@cec.com | Demo123! | entrega_despacho |

## Clientes

| Client | Email | Password |
|:-------|:------|:---------|
| Juan Perez (CEC-001) | juan.perez@gmail.com | Cliente123! |
| Maria Lopez (CEC-002) | maria.lopez@hotmail.com | Cliente123! |
| Carlos Reyes (CEC-003) | carlos.reyes@yahoo.com | Cliente123! |
| Ana Martinez | ana.mtz@gmail.com | Cliente123! |
| Roberto Hernandez | roberto.h@gmail.com | Cliente123! |
| Sofia Garcia | sofia.g@outlook.com | Cliente123! |
| Diego Flores | diego.flores@gmail.com | Cliente123! |
| Lucia Rivera | lucia.r@gmail.com | Cliente123! |
| Pedro Mejia | pedro.mejia@yahoo.com | Cliente123! |
| Carmen Santos | carmen.s@hotmail.com | Cliente123! |

> All demo clientes share the same password. Carlos Reyes is **inactive** and cannot log in.

## Demo Data

- **20 paquetes** across various states (recibido, etiquetado, enviado, etc.)
- **2 manifiestos** (one creado, one enviado)
- **3 pre-alertas**:
  - PA-000001 — Juan, aereo, reempaque, 2 paquetes
  - PA-000002 — Maria, maritimo, consolidado, recibido, 1 paquete
  - PA-000003 — Juan, aereo, 1 paquete
