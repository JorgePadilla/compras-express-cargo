# CEC — Fases de Implementacion

60 modelos · 116 migraciones · 1879 tests · Rails 8 + Hotwire + Tailwind CSS 4 + PostgreSQL 17

```
Pre-alerta → Recepcion Miami → Manifiesto → Pre-factura → Factura → Pago → Entrega
```

> **Ojo con el orden.** La **pre-factura se hace en San Pedro, antes** de mandar
> el paquete a cualquier sucursal, porque el personal de prefactura existe solo
> ahí (`A7-01`, Conversación 7). El diagrama de procesos lo tenía al revés.

---

## Series de PR

Conviven cuatro numeraciones, y no todas se siguen en este archivo. Antes de
buscar un PR, mirá acá dónde vive:

| Serie | Qué es | Dónde se sigue |
|---|---|---|
| `PR-{fase}.{letra}` | El trabajo de una fase numerada: `PR-9.a`, `PR-10.h`, `PR-13.e` | **Este archivo**, en la sección de su fase |
| `PR-D{n}.{letra}` | Fase 5c — Detalle de Paquete + Warehouse Receipt. La letra es la iteración: `PR-D1.d` es la cuarta pasada de D1 | **Este archivo**, Fase 5c |
| `PR-C6.{nn}` | Todo lo que salió de la **Conversación 6** — va del `C6.18` al `C6.48`, y es la mayor parte del trabajo de agosto 2026 | **`docs/05`**, no acá. Un solo dueño por dato |
| `PR-BTN.{n}` | Refactor transversal a `ButtonComponent`. No cuelga de ninguna fase | Historial de git y `docs/07` |

La serie `RP-{nn}` **no son PRs**: son las preguntas al cliente. Viven en
`docs/05` y salen impresas en `docs/entregables/preguntas_para_yusef.pdf`.

---

## Fase 0: Fundacion (Rails scaffold + auth + deploy) ✅ COMPLETA

**Objetivo:** App corriendo en staging con login, roles y layout base.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 0.1 | Rails 8 new + PostgreSQL + Tailwind 4 + Hotwire | — | ✅ |
| 0.2 | Autenticacion (Rails 8 generator) + sesiones | 1 | ✅ |
| 0.3 | Modelo User con 9 roles + enum + ubicacion (miami/honduras) | 2 | ✅ |
| 0.4 | Sistema de autorizacion por rol (qué ve cada quien) | 2 | ✅ |
| 0.5 | Layout responsive: sidebar admin + sidebar cliente (Mi Cuenta) | 3, 4 | ✅ |
| 0.6 | Plantilla base reutilizable (busqueda + filtros + tabla + paginacion) | 8 (patron UI) | ✅ |
| 0.7 | Seeds: tipos envio, carriers, empresas manifiesto, categorias precio, admin user | Config | ✅ |
| 0.8 | Deploy a Render staging + CI/CD GitHub Actions | Infra | ✅ |
| 0.9 | Modelo Cliente + CRUD basico | 11 | ✅ |

**Entregable:** Login funcional, 2 portales (admin/cliente), layout responsive, deploy automatico.

**Dependencia:** Ninguna.

---

## Fase 1: Flujo Miami (el core del negocio) ✅ COMPLETA

**Objetivo:** Digitadores en Miami pueden etiquetar paquetes y armar manifiestos.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 1.1 | Modelo Paquete con estados (enum), tracking, dimensiones | 7 | ✅ |
| 1.2 | Pantalla Etiquetar/Digitar — formulario con 18 campos, atajos F2/F8/F9 | 6 | ✅ |
| 1.3 | Autocomplete de cliente por codigo (C5344) con Turbo | 6 | ✅ |
| 1.4 | Notas del cliente por ubicacion (Miami/Honduras) visibles al etiquetar | 34 | ✅ |
| 1.5 | Sonidos: confirmacion al guardar, error en duplicados, alerta en notas | 33 | ✅ |
| 1.6 | Deteccion de tracking duplicado/reciclado con historial | 36 | ✅ |
| 1.7 | Soporte 1 tracking → multiples cajas (caso DHL) | 36 | ✅ |
| 1.8 | Impresion de etiquetas (F9) | 6 | ✅ |
| 1.9 | Modelo Manifiesto + CRUD: crear, agregar paquetes, enviar | 8 | ✅ |
| 1.10 | Vista Todos los Paquetes con filtros avanzados + leyenda colores | 7 | ✅ |

**Entregable:** Miami operativo — digitadores etiquetan, supervisores crean manifiestos.

**Dependencia:** Fase 0 completa.

---

## Fase 2: Pre-Alertas (cliente + admin) ✅ COMPLETA

**Objetivo:** Clientes crean pre-alertas desde Mi Cuenta, admin las gestiona.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 2.1 | Portal Cliente (Mi Cuenta): dashboard con quick links, sidebar | 3 | ✅ |
| 2.2 | Modelo PreAlerta + asociacion con paquetes | 5 | ✅ |
| 2.3 | Wizard de 3 pasos cliente (v4): Servicio → Consolidacion → Datos | 5 | ✅ |
| 2.4 | Editor Pre-Alerta cliente: agregar trackings, contenido, badges | 5 | ✅ |
| 2.5 | Vista lista Pre-Alertas cliente (cards en grid) | 5 | ✅ |
| 2.6 | Vista lista Pre-Alertas admin (tabla con filtros, 12k+ registros) | 5 | ✅ |
| 2.7 | Admin: Crear/Editar pre-alerta con atajos F6/F8/F9 | 5 | ✅ |
| 2.8 | Vinculacion automatica: paquete etiquetado en Miami ↔ pre-alerta existente | 5, 6 | ✅ |
| 2.9 | Notificaciones al cliente (email) al recibir paquete en Miami | 5 | ✅ |
| 2.10 | Boton "Limpiar Vacias" + job automatico | 5 | ✅ |

**Entregable:** Flujo completo Pre-alerta → Recepcion Miami conectado.

**Dependencia:** Fase 1 (etiquetar debe existir).

---

## Fase 3: Facturacion y Cobro

**Objetivo:** Pre-facturas, ventas, pagos y recibos funcionando.

### Fase 3a — Core Billing MVP ✅ COMPLETA (Abril 2026)

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 3.1 | Modelo PreFactura: generacion desde paquetes recibidos/pesados | 9 | ✅ |
| 3.2 | Vista Pre-Facturas admin + cliente | 9 | ✅ |
| 3.3 | Categorias de precio por cliente (precio/libra aereo, maritimo, volumen) | 11 | ✅ |
| 3.4 | Calculo automatico: peso cobrar = max(peso real, peso volumetrico) | 9 | ✅ (Fase 1) |
| 3.5 | Modelo Venta + items (proforma → pendiente → pagada → anulada) | 12 | ✅ |
| 3.6 | Modelo Recibo + generacion al pagar | 16 | ✅ |
| 3.7 | Modelo Pago (efectivo, tarjeta, transferencia) | — | ✅ |
| 3.12 | Facturas Pendientes (vista cliente) | 15 | ✅ |

**Entregable:** Ciclo completo Pre-factura → Venta → Pago → Recibo en LPS con ISV 15%.

### Fase 3b — Notas D/C + PDFs + Emails ✅ COMPLETA (Abril 2026)

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 3.8 | Notas de Debito (admin CRUD + cuenta read-only) | 17 | ✅ |
| 3.9 | Notas de Credito (admin CRUD + cuenta read-only) | — | ✅ |
| 3b.1 | Modelo Empresa (singleton, datos fiscales para PDFs) | — | ✅ |
| 3b.2 | Prawn PDFs: Venta, Recibo, NotaDebito, NotaCredito | — | ✅ |
| 3b.3 | Mailers: FacturaMailer, NotaDebitoMailer, NotaCreditoMailer | — | ✅ |

**Entregable:** Documentos fiscales completos con PDFs y envio por email.

### Fase 3c — Cotizaciones + Proformas + Financiamientos + Dual Currency ✅ COMPLETA (Abril 2026)

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 3.10 | Cotizaciones (borrador→enviada→aceptada/rechazada/expirada) + PDF + Email | 13 | ✅ |
| 3.11 | Proformas (vista filtrada de Venta con estado=proforma, emitir→pendiente) | 14 | ✅ |
| 3.12 | Financiamientos (cuotas semanal/quincenal/mensual, pagar_cuota genera Pago+Recibo) | 18 | ✅ |
| 3c.1 | Dual Currency LPS/USD (CurrencyAware concern + ActualizarTasaCambioJob vía FloatRates) | — | ✅ |

**Entregable:** Cotizaciones con PDF, proformas emitibles, financiamientos con cuotas, soporte USD/LPS.

**Dependencia:** Fase 3a (billing core).

---

### Extras (entre fases) ✅

| Tarea | Estado |
|-------|--------|
| Admin Users CRUD (8 roles, activo toggle, buscar) | ✅ Abril 2026 |
| Client Self-Registration (`/registro`) | ✅ Abril 2026 |
| UI polish: mobile responsive, admin pre-alerta form redesign | ✅ Abril 2026 |
| Pre-Alerta UX: stepper details, unified wizard flow, auto-save on move/delete | ✅ Abril 2026 |
| Pre-Alerta wizard: client-side draft persistence (localStorage) + BORRADOR card | ✅ Abril 2026 |
| Pre-Alerta wizard: stepper simplify (selection as label on completed steps) | ✅ Abril 2026 |
| Pre-Alerta wizard: auto-open blank paquete row after "Agregar Otro Paquete" | ✅ Abril 2026 |
| Pre-Alerta rules matrix (Abril 2026): CKA/CKM unlinked moves + linked delete + notas_editables? | ✅ Abril 2026 |

**Test suite:** 620 tests passing.

---

## Fase 4: Caja y Entrega ✅ COMPLETA (Abril 2026)

**Objetivo:** Cajeros procesan pagos diarios, despacho entrega paquetes. Completa el loop operativo.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 4.1 | Modelo Entrega: despachar!/entregar!/anular!, receptor, identidad, paquetes | 10 | ✅ |
| 4.2 | Vista Entregas admin: lista + busqueda + filtros por estado/repartidor | 10 | ✅ |
| 4.3 | Crear Entrega: seleccionar paquetes facturados, registrar receptor | 10 | ✅ |
| 4.4 | Flujo facturado → en_reparto → entregado con transiciones validadas | 10 | ✅ |
| 4.5 | Mi Dia dashboard: apertura/cierre caja, resumen, ingresos/egresos del dia | 19 | ✅ |
| 4.6 | Modelo IngresoCaja + CRUD (ingresos extras a caja) | 20 | ✅ |
| 4.7 | Modelo EgresoCaja + CRUD (egresos de caja) | 20 | ✅ |
| 4.8 | Pago auto-link a AperturaCaja abierta del dia | — | ✅ |
| 4.9 | Numero de entrega via PostgreSQL sequence (concurrency-safe) | — | ✅ |
| 4.10 | Vista Mis Entregas (cliente) | 10 | ✅ |

**Entregable:** Caja operativa en Honduras + entregas registradas + portal cliente.

**Dependencia:** Fase 3a (ventas y pagos deben existir). ✅ Cumplida.

---

## Fase 5: Tareas y Re-empaque (mejoras Miami) ✅ COMPLETA (Abril 2026)

**Objetivo:** Sistema de tareas para operaciones especiales + registro de re-empaque con dimensiones.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 5.1 | Modelo Tarea asociada a paquete (checklist operador) | 32 | ✅ PR #66 |
| 5.2 | Estados tarea: pendiente → en proceso → realizada + CRUD admin | 32 | ✅ PR #67 |
| 5.3 | Paquete no avanza hasta completar todas sus tareas (guard en model) | 32 | ✅ PR #67 |
| 5.4 | Re-empaque como tarea/servicio: tracking de quien lo hizo | 2, 37 | ✅ PR #69 |
| 5.5 | Registro dimensiones antes/despues, calculo ahorro volumen | 37 | ✅ PR #69 |

**Entregable:** Operaciones especiales en Miami sistematizadas.

**Dependencia:** Fase 1 (etiquetar) + Fase 2 (pre-alertas).

**Modelos nuevos:** `Tarea` (pendiente/en_proceso/realizada, asignado_a, completado_por), `Reempaque` (snapshot antes/después de dimensiones, cálculo de ahorro volumétrico, vinculación opcional a Tarea).

**Reglas clave implementadas:**
- Tareas abiertas bloquean el avance del paquete en el pipeline operativo (`Paquete::ESTADOS_ORDEN` validation en el modelo).
- Estados laterales (`anulado`, `retornado`, `desechado`, `retenido`) no se bloquean; admin puede transicionar a ellos aunque haya tareas.
- Re-empaque: al crear, snapshot automático de dimensiones actuales del paquete; después de guardar, actualiza el paquete con las nuevas dimensiones (recalcula `peso_volumetrico` y `peso_cobrar` via `before_save` existentes).
- Si el Reempaque está vinculado a una Tarea, completarla al guardar.

**Nota (2026-04-24):** Las tareas de **Fotos de paquetes** (antes 5.6–5.8) se movieron a una fase posterior (Fase 9) para priorizar el flujo operativo core y postergar la decisión de storage (R2 vs Render Disk vs S3).

---

## Fase 5b: Recepción — Mejoras de Numeración y Tracking

**Objetivo:** Adaptar el flujo de recepción Miami a los requerimientos confirmados por el cliente (Yusef, 2026-04-25): nuevo formato anual de `numero_recepcion`, flow guiado para tracking duplicado y soporte para sub-etiquetas (división de tracking en N bultos).

**Decisión:** Se implementa en **PRs separados** porque tocan capas distintas (data layer vs. UX/endpoint).

| # | Tarea | PR | Estado |
|---|-------|----|----|
| 5b.1 | Nuevo formato `numero_recepcion` anual (`RM0002026000001`): `<prefix><año 7-dig><contador-año 6-dig>`. Reemplaza la sequence corrida por contador atómico `(sucursal_id, año)`. Reinicia 1° de enero. | PR-A | ✅ #79 |
| 5b.2 | Flow guiado de tracking duplicado: modal con 2 opciones (`Es actualización` vs. `Es tracking repetido`) + sufijo letras automático (`A`, `B`, `C`, …). | PR-B | ⏳ Listo para implementar |
| 5b.3 | Sub-etiquetas: división de un tracking en N bultos (1/3, 2/3, 3/3). Principal en Miami (al recibir); también en Honduras vía pre-factura. | PR-C | ⏳ Bloqueado por respuestas cliente |

**Dependencia:** Fase 1 (etiquetar/recepción operativa).

**Detalle PR-A — Nuevo formato `numero_recepcion`:** ✅ Implementado.
- Tabla `numero_recepcion_counters(sucursal_id, anio, ultimo_numero)` con unique index.
- `NumeroRecepcionCounter.next_for!` usa `lock!` (`SELECT FOR UPDATE`) para serializar bajo concurrencia.
- `Paquete#generate_numero_recepcion` formatea con `format("%<prefix>s%<anio>07d%<num>06d", …)`.
- Decisiones por default: 6 dígitos contador (1M/año), no migrar históricos (coexisten formatos), prefijo via `codigo_recepcion_prefix` existente (regex `[A-Z]{1,4}`).

**Detalle PR-B — Flow tracking duplicado** (decisiones tomadas, Yusef 2026-04-25):
- Endpoint `check_tracking` existente (`PaquetesController#check_tracking`) extender response JSON con `existing_paquete_id`, `tracking_base`, `next_suffix`.
- Stimulus controller en `etiquetar` (y opcionalmente `paquetes/_form`) que muestre modal al detectar duplicado con dos opciones explícitas.
- Helper Ruby `Paquete.next_duplicate_suffix(tracking_base)` calcula la próxima letra libre (`A`→`B`→…→`Z`).
- **Comportamiento al pasar `Z`:** parar y pedir intervención manual del supervisor (caso extremadamente raro). No se extiende a `AA` por ahora.
- **Modo "actualización":** carga la recepción original en el form de edit estándar — el digitador puede cambiar **cualquier campo**.
- **Auditoría:** sin bitácora dedicada en este PR; `updated_at` y logs estándar son suficientes. Se evalúa agregar reportes específicos como follow-up si el supervisor los pide.
- Mantener uniqueness en `paquetes.tracking` (los sufijos hacen cada tracking único).

**Detalle PR-C — Sub-etiquetas (1/3, 2/3, 3/3):**
- Caso de uso: un mismo `tracking` se recibe físicamente como N bultos. Cada uno lleva un identificador `<n>/<N>`.
- Existen ya `paquetes.numero_caja` y `paquetes.cantidad_paquetes` (módulo 36 — multi-caja DHL). Probablemente reutilizables.
- Pendiente confirmar:
  - ¿Se reusa `cantidad_paquetes` o se necesitan columnas nuevas (`numero_caja_secuencia`, `total_cajas_tracking`)?
  - ¿La notación `1/3` se imprime en la etiqueta física? ¿forma parte del `numero_recepcion` o queda en una columna aparte?
  - ¿Los N paquetes comparten `numero_recepcion` con sufijo, o cada uno tiene `numero_recepcion` propio?
  - UX en Etiquetar: ¿el digitador indica "dividir en 3 cajas" y el sistema crea los 3 paquetes automáticamente, o cada uno se etiqueta individualmente?
  - En Honduras: ¿ya existe el flow vía pre-factura (Roger lo construyó) o también se diseña aquí?

**Preguntas abiertas con el cliente (bloquean implementación):**
- PR-C únicamente: estructura de columnas; UX de "dividir en N"; estado actual del flow de pre-factura en Honduras.

**Referencia:** `docs/05_requerimientos_conversaciones.md` secciones 5.1, 6 y 6.1.

---

## Fase 5c: Detalle de Paquete + Warehouse Receipt (PR-D series)

**Objetivo:** Rediseño completo de la vista detalle/edit del paquete y del Warehouse Receipt según spec del cliente (2026-04-29). Ver `docs/05_requerimientos_conversaciones.md` Conversación 3.

| # | Branch / PR | Scope | Estado |
|---|-------------|-------|--------|
| 5c.0 | `fix/numero-recepcion-compartido-split` | `numero_recepcion` compartido entre las N cajas del split (madre único). Unique compuesto `(numero_recepcion, numero_caja)`. | ✅ #84 |
| 5c.WR | `feat/warehouse-receipt-redesign` | Rediseño `label.html.erb` al WR completo (header empresa Miami LLC, banner navy, columnas Shipper/Consignee/Agent, tabla packages, totales LB/KG/cuft/m³, T&C bilingüe). | ✅ #85 |
| 5c.5 | `feat/warehouse-receipt-model` | Modelos nuevos: `WarehouseReceipt` + `Supplier` + `Agent` + `Terms`. Migra `paquetes.numero_recepcion` → `paquetes.warehouse_receipt_id`. **Antecede a D1-D4.** | ⏳ Listo para implementar |
| 5c.1 | `feat/paquete-estados-fechas-audit` | Nuevo estado `pre_alerta`, ~7 fechas + `*_user_id` por fecha, `users.iniciales` (campo nuevo editable), `paper_trail` + UI bitácora. **Indicador visual "modificada"** en fechas re-editadas (ej. `fecha_recibido_miami`). Job nocturno de "disponible programada" con notif email/SMS/WhatsApp/push a las 7am. Modelo `SubLocalidad` + `sucursal_actual_id`/`sub_localidad_actual_id` en paquetes. Recolecta fija $35 USD editable. **Manifiesto formato anual `MM2026000001`** (counter por sucursal/año, análogo a `numero_recepcion`). **`paquetes.tracking_secundario`** (string, nullable) — vinculación de PA matchea ambos trackings. | ✅ Listo para implementar |
| 5c.2 | `feat/paquete-notas-categorizadas` | Refactor notas (especiales PA, consolidación PA, retención, internas, al_cliente). Notas permanentes del cliente como modal por área (`notas_miami`, `notas_honduras`, **`notas_caja` NUEVA**, **`notas_sac` NUEVA**). **Plantillas de notas al cliente** (modelo `PlantillaNotaCliente` + picker, compartidas entre Etiquetar/Pre-Factura/Caja/SAC). Notas al cliente viajan en email de notificación. **Notas de retención obligatorias en estado `retenido`** + modelo `MotivoRetencion` con multi-select de motivos. | ✅ Listo para implementar |
| 5c.3 | `feat/paquete-tercero-proveedor-services` | `tercero_nombre` (string libre, no FK), `Proveedor` modelo con dropdown + opción "Otros" (texto libre), flow ENTREGA PERSONAL con tracking auto generado (`<SUCURSAL>-<YYYYMMDD>-<correlativo>`), `service_code` enum, `repackaging_type` enum, `consolidation` bool. **`paquetes.carrier_id` FK al modelo `Carrier` existente** (UPS/USPS/DHL/FedEx). | ⏳ Bloqueado solo por pregunta 14b (empresa transporte) |
| 5c.4 | `feat/paquete-show-actions` | ~10 botones del header del show (mover/eliminar PA, copy buttons, ver pre-factura/factura). **Re-imprimir Etiquetas Miami: preview con checkboxes para seleccionar cuáles imprimir** (1 por página). **Imprimir Pre-Factura: preview + imprimir + copiar imagen para enviar al cliente.** **Botón "Refrescar"** visual estilo Gmail (icono ↻). El WR ya está hecho en 5c.WR. | ✅ Listo para implementar |

**Dependencia:** Fase 5b (numero_recepcion anual + split). ✅ Cumplida.

**Decisiones de arquitectura confirmadas (Jorge + Yusef, 2026-04-28..29):**
- `numero_recepcion` compartido en split, formato `RM0002026000001` (15 chars, no `RM2026ZN000000001`).
- `WarehouseReceipt` modelo separado de `Paquete`. `has_many :packages`.
- `Supplier` (Proveedor) modelo nuevo con código manual + CRUD admin.
- `Agent` modelo nuevo opcional + CRUD admin.
- `Terms` modelo versionable, texto genérico bilingüe inicial.
- Audit log con `paper_trail` gem (no custom).

**Respuestas confirmadas para PR-D1 (estados/fechas/audit) — 2026-04-29:**

1. **Disponible programada:** se llena al crear pre-factura; job a las 7am cambia estado + dispara notif (email + SMS/WhatsApp + push browser).
2. **Re-modificación de fechas:** `fecha_pre_alerta` queda original. Empacado/Enviado/Aduana/Consolidando/Disponible/Recibido_miami se sobrescriben. Log conserva histórico. **Indicador visual de "modificada"** cuando `fecha_recibido_miami` (o cualquier fecha sobreescribible) ya tuvo cambio previo (badge `(modificada)` o icono lápiz, hover muestra original + última edición). Aprovecha `paper_trail` versions.
3. **Iniciales:** campo nuevo `users.iniciales` editable al crear/editar usuario en CRUD admin (no calculado del nombre).
4. **Bodega = Sucursal + Sub-localidad.** Sucursales actuales: **Zerón SPS** + **Humuya TGU**. Sub-localidades dentro de cada sucursal (ej. `ZR01` bodega central, `ZR02` bodega CEM). Modelo nuevo `SubLocalidad`. Paquete tiene `sucursal_actual_id` + `sub_localidad_actual_id` (físico, al escanear) y `sucursal_destino_id` (del manifiesto).
5. **Fecha posible de entrega:** `tipos_envio.dias_estimados` + `fecha_recibido_miami`. Al ir a manifiesto se actualiza con fecha del manifiesto. Override manual via `fecha_posible_entrega_override`.
6. **Modificar fecha posible:** admin + supervisor_miami + supervisor_prefactura.
7. **Recolecta:** ~~tarifa fija $35 USD~~ → **corregido (Yusef):** la tarifa cambia por zona y cantidad, así que se implementó el modelo **`TarifaRecolecta`** (catálogo configurable con CRUD admin) en vez del monto fijo. Sigue siendo editable inline por el cajero. Ver `paquetes.tarifa_recolecta_id`.
8. **Audit log access:** **admin + TODOS los supervisores** (`supervisor_miami`, `supervisor_caja`, `supervisor_prefactura`). NO incluye SAC/cajero/digitador/entrega_despacho.

**Respuestas confirmadas para PR-D2 (notas) — 2026-04-29:**

9. **Notas permanentes del cliente:** se reusan `clientes.notas_miami`/`notas_honduras` y se agregan **`notas_caja`** y **`notas_sac`** (nuevas). UI: modal automático al abrir paquete, filtrado por área del usuario actual (Miami / Caja+HND / SAC / Pre-Factura ve combos / Admin ve todas).

12. **Notas al cliente:** flujo: Etiquetar **inicia** → email de notificación al cliente lleva esa nota → Pre-Factura/Caja/SAC **adicionan** (no sobrescriben). NUEVO: **modelo `PlantillaNotaCliente`** + dropdown picker en el form para insertar plantillas de texto recurrente. Compartidas entre las 4 áreas.

10. **Notas de retención:** **OBLIGATORIAS** cuando el paquete pasa a estado `retenido` (validation). Multi-select de motivos desde catálogo (modelo nuevo `MotivoRetencion`) + textarea de detalle libre adicional.

**Respuestas confirmadas para PR-D3 (tercero/proveedor) — 2026-04-29:**

11. **Proveedor:** dropdown con pre-determinados (Amazon, eBay, Walmart, Sams, Target, ENTREGA PERSONAL) + opción **"OTROS"** que activa input de texto libre. Modelo `Proveedor` con CRUD admin.
12. **ENTREGA PERSONAL:** ~~formato `<SUCURSAL>-<YYYYMMDD>-<correlativo>`~~ → **corregido (Yusef):** el formato final es **`EP-AÑO-SUC-PROV-NNNNNN`** (ej. `EP-2026-SM-AMZ-000001`) — correlativo **anual**, no diario, con el código del proveedor incluido. Modelo `EpCounter` + `sucursales.codigo_ep` + `proveedores.codigo` (3 letras). Además dejó de ser "formulario adicional" dentro de etiquetar: en PR-6a se separó a su **propia pantalla** `/entrega_personal/new`, porque mezclarlo con el etiquetado normal confundía al digitador.
14. **Tercero:** **texto libre** (no Cliente registrado). Flujo de revendedor: `cliente_id` = revendedor; `tercero_nombre` = cliente final del revendedor. Etiqueta y WR muestran ambos.
15. **Cliente vs tercero:** revendedor en `cliente_id` (registrado en CEC), tercero en `tercero_nombre` (texto libre).

**Respuestas confirmadas para PR-D4 (botones) — 2026-04-29:**

15. **Re-imprimir Etiquetas Miami:** preview de todas las etiquetas hermanas con **checkboxes** → digitador marca cuáles imprimir → una etiqueta por hoja. Ej: paquete de 4 cajas → digitador marca solo 2/4 y 3/4 → 2 hojas impresas.
16. **Botón "Refrescar":** botón visual con icono de refresh (↻) estilo Gmail — solo recarga la página completa. Equivalente visual a F5.
- **Imprimir Pre-Factura desde paquete:** preview de la pre-factura completa + botón imprimir + sirve para que el agente copie imagen y envíe al cliente.
- **F2 universal:** Stimulus controller reutilizable para limpiar parámetros/filtros del form actual en TODOS los módulos (extender el F2 ya existente en etiquetar/paquetes).

**Respuesta confirmada para PR-D3 (carrier):** 13. **Carrier:** FK al modelo `Carrier` existente (UPS/USPS/DHL/FedEx). Backfill best-effort matching `expedido_por` string → `carriers.nombre`.

**Respuesta confirmada general:** 17. **Manifiesto formato `MM2026000001`:** se incluye en **PR-D1** junto con estados/fechas. Counter por sucursal/año análogo a `numero_recepcion_counters`.

**Requisito agregado por Yusef 2026-04-29 (refinamiento spec original):** 

**Segundo tracking** (`paquetes.tracking_secundario`): muchos paquetes llegan con 2 números de seguimiento (el proveedor le da uno al cliente para la pre-alerta y otro al paquete físico). El sistema acepta ambos en el form, los indexa, y `PreAlertaPaquete.link_tracking!` matchea contra cualquiera de los dos. Búsqueda incluye ambos. WR/etiquetas muestran principal + "Alt:" debajo si existe secundario. **Se incluye en PR-D1.**

**Pregunta pendiente para Yusef (única restante):**
- 14b. Empresa transporte vs manifiesto: cuando un paquete cambia de manifiesto, ¿muestra la empresa actual del manifiesto (heredada) o la empresa original con la que viajó (redundante en paquete)?

**Referencia:** `docs/05_requerimientos_conversaciones.md` Conversación 3.

---

## Fase 9: Fotos de Paquetes (Miami)

**Objetivo:** Capturar fotos en la estación de recepción y asociarlas al paquete con envío al cliente.

| # | Tarea | Modulos |
|---|-------|---------|
| 9.1 | Fotos de paquetes: captura desde camaras de estacion (2 camaras) | 35 |
| 9.2 | Active Storage + bucket externo (Cloudflare R2 / S3 / Render Disk) | 35 |
| 9.3 | Fotos en email de notificacion al cliente | 35 |

**Dependencia:** Fase 5 (tareas, el re-empaque usa fotos).

**Pendiente de decisión:** Provider de storage. Opciones consideradas:
- Cloudflare R2 (recomendado: S3-compatible, sin egress, 10 GB free tier).
- Render Persistent Disk ($0.25/GB/mes, ata a single-instance, sin CDN).
- Backblaze B2 (el más barato por GB, egress pagado).

---

## Fase 6: Reportes, Dashboard y Configuraciones

**Objetivo:** Visibilidad completa del negocio + administracion.

| # | Tarea | Modulos | Estado |
|---|-------|---------|--------|
| 6.1 | Dashboard admin con estadisticas (graficas, KPIs) | 30 | ✅ PR #70 |
| 6.2 | 12 reportes (por definir detalle de cada uno) | 29 | ⏳ |
| 6.3 | 22 catalogos de configuracion (CRUD para cada uno) | 28 | ⏳ |
| 6.4 | Costos de empresa (/Mantenimientos/) | 31 | ⏳ |
| 6.5 | Tasa de cambio LPS/USD configurable (UI admin) | 28 | ⏳ |
| 6.6 | Calculadora de costos mejorada (cliente) | 38 | ⏳ |
| 6.7 | Seguimiento publico de paquete (sin login) | 39 | ⏳ |

**Entregable:** Admin tiene control total, cliente tiene visibilidad.

**Dependencia:** Fases 1-4 (necesita datos reales para reportes).

**6.1 Dashboard Admin (Abril 2026):**
- 4 KPIs del día: ingresos LPS, paquetes recibidos Miami, entregas realizadas, pre-alertas nuevas (con contexto semana/mes).
- Pipeline operativo: en bodega, en tránsito, disponibles entrega, ventas pendientes.
- Gráfica 7 días de paquetes recibidos (CSS puro, 1 query `GROUP BY DATE`).
- Actividad reciente: últimos 8 paquetes + últimas 5 ventas con eager loading `includes(:cliente)`.
- Autorización explícita por rol (`DASHBOARD_ROLES = [admin, supervisor_miami, supervisor_caja, supervisor_prefactura]`); otros roles son redirigidos a su sección apropiada.
- Separación admin/cliente: `redirect_cliente_to_portal` before_action detecta ClienteSession y redirige a `cuenta_root_path`.
- Refactor: métricas extraídas a `app/queries/dashboard_metrics.rb` (query object); controller queda slim.
- Test anti-N+1: el suite incluye un caso que cuenta queries en `sql.active_record` notifications y asserta cota ≤ 35.

---

## Fase 7: Marketing CRM

**Objetivo:** Comunicacion masiva con clientes.

| # | Tarea | Modulos |
|---|-------|---------|
| 7.1 | Campanas de marketing (crear, programar, enviar) | 21 |
| 7.2 | Correos masivos (cola de 100/clic) con Solid Queue | 22 |
| 7.3 | Integracion WhatsApp (API) | 23 |
| 7.4 | Integracion SMS | 23 |
| 7.5 | URL Links (tracking de clics marketing) | 24 |

**Entregable:** CRM basico operativo.

**Dependencia:** Fase 0 (clientes) + Fase 6 (configuraciones).

---

## Fase 8: Inventario y Productos

**Objetivo:** Control de productos e inventario.

| # | Tarea | Modulos |
|---|-------|---------|
| 8.1 | Modelo Producto + CRUD | 25 |
| 8.2 | Ajustes de inventario | 26 |
| 8.3 | Traslados de inventario (Miami ↔ Honduras) | 27 |

**Entregable:** Inventario controlado.

**Dependencia:** Fase 0 (base).

---

## Resumen Visual

```
Fase 0  ████████████████████  Fundacion (auth, roles, layout, deploy)     ✅
Fase 1  ████████████████████  Miami (etiquetar, manifiestos)              ✅
Fase 2  ████████████████████  Pre-Alertas (cliente + admin + v4)          ✅
Fase 3a ████████████████████  Billing MVP (prefactura→venta→pago→recibo)  ✅
Fase 3b ████████████████████  Notas D/C + PDFs + Emails                   ✅
Fase 3c ████████████████████  Cotizaciones + Proformas + Financiamientos  ✅
Fase 4  ████████████████████  Entregas + Caja Diaria                      ✅
Extras  ████████████████████  Users CRUD + Registro + UI polish           ✅
Fase 5  ████████████████████  Tareas + Re-empaque (5.1–5.5)              ✅
Fase 5b ████████████████████  Recepcion — Numeracion y Tracking           ✅
Fase 5c ████████████░░░░░░░░  Detalle de Paquete + WR (PR-D series)     ← EN CURSO
Fase 6  ███░░░░░░░░░░░░░░░░░  Reportes + Config + Dashboard (6.1 ✅)    ← EN CURSO
Fase 7  ░░░░░░░░░░░░░░░░░░░░  Marketing CRM
Fase 8  ░░░░░░░░░░░░░░░░░░░░  Inventario
Fase 9  ░░░░░░░░░░░░░░░░░░░░  Fotos de Paquetes (storage + envio a cliente)
Fase 10 ████████████████░░░░  Contexto operativo en captura (PR-9)      ← EN CURSO
Fase 11 ████████████████░░░░  Tarifas y calculo de cobro (PR-10)        ← EN CURSO
Fase 12 ████████████████████  Manifiesto de punta a punta (PR-M1–M9)      ✅
Fase 13 ████████████████████  Precio bloqueado + PIN de supervisor        ✅
```

> El trabajo de agosto 2026 **no aparece en este cuadro**: es la serie `PR-C6`
> (del `C6.18` al `C6.48`) y se sigue en `docs/05`. Ver "Series de PR" arriba.

**Fases paralelas posibles:**
- Fase 5 puede correr en paralelo con Fase 3
- Fase 7 y 8 pueden correr en paralelo con Fase 6

---

## Orden de Prioridad (lo que el negocio necesita primero)

1. **Fase 0 + 1:** Sin Miami no hay negocio
2. **Fase 2:** Sin pre-alertas el cliente no puede usar el sistema
3. **Fase 3 + 4:** Sin cobro y entrega no hay revenue
4. **Fase 5:** Mejoras operativas Miami (diferenciador)
5. **Fase 6:** Visibilidad y control
6. **Fase 7 + 8:** Nice to have, no bloquea operacion

---

## Reglas de Negocio — Pre-Alertas

1. **Notas de Consolidacion**: Solo visible para pre-alertas consolidadas. No aplica para CKA/CKM ni servicios sin consolidar (CER/CEM/EXPRESS sin consolidar). Editables mientras `consolidando?` Y ningún paquete vinculado haya llegado a `en_aduana` o posterior (`PreAlerta#notas_editables?`). Una vez bloqueadas se renderizan en modo solo lectura.
2. **Finalizar Consolidacion**: Al finalizar una pre-alerta consolidada:
   - Se marca `finalizado=true` y `notificado=true`
   - Todos los campos quedan en modo solo lectura
   - No se pueden agregar, mover ni eliminar paquetes
   - No se aceptan paquetes movidos desde otras pre-alertas
   - Las notas de consolidacion se bloquean
   - Se muestra badge "Consolidado Finalizado" en la interfaz
3. **Historial de Movimientos**: Registro automatico, no editable, separado de las notas del usuario. Incluye: timestamp, tracking, descripcion del paquete, PA origen/destino con titulo. Al mover un paquete, las `notas_grupo` del origen se anexan como sufijo (`Notas del grupo origen: "..."`) a las entradas de origen Y destino, preservando contexto sin mutar las notas del destino.
4. **Tipos de Servicio en Cards**: Las tarjetas de pre-alertas muestran el titulo como identificador principal, el codigo de servicio (CER, CEM, EXPRESS) con su descripcion (Aereo con Reempaque, etc.), y el estado de consolidacion.
5. **Matriz Mover / Eliminar paquetes (Abril 2026)**:

   | Estado del Paquete | Origen CONSOLIDANDO (EXP/CER/CEM) | Origen SIN CONSOLIDAR (EXP/CER/CEM) | Origen CKA/CKM |
   |---|---|---|---|
   | **PRE_ALERTA** (no vinculado) | Mover a cualquier PA consolidando CER/CEM/EXP · eliminar PAP | Igual | Igual |
   | **recibido_miami / empacado / enviado_honduras** (vinculado) | Mover a PA consolidando del mismo tipo · eliminar PAP (el paquete queda en bodega) | Igual | BLOQUEADO |
   | **en_aduana** en adelante | BLOQUEADO | BLOQUEADO | BLOQUEADO |

   Implementación: `ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras]`, `puede_mover?(pap)` y `puede_eliminar?(pap)` en `Cuenta::PreAlertasController`. Eliminar un PAP vinculado destruye sólo la fila de unión; el `Paquete` físico permanece intacto en la bodega.
6. **Wizard Cliente**: Stepper de 3 pasos (Servicio → Consolidación → Datos) con persistencia en localStorage (draft BORRADOR en Mis Pre-Alertas). Al completar un paso, el stepper muestra la selección como label. En el paso 3, "Agregar Otro Paquete" guarda el primer paquete y abre automáticamente una fila en blanco en el editor.


---

## Filtros en /paquetes

El listado `/paquetes` (admin) tiene un panel "Filtros avanzados" colapsable con los siguientes controles:

### Filtros disponibles
- **Búsqueda libre** (`params[:q]`): scope `Paquete.buscar` que matchea tracking, tracking_secundario, guía, número de recepción, descripción, código/nombre/apellido del cliente, código/nombre del tipo de envío y número de manifiesto.
- **Tipo de envío** (`params[:tipo_envio_ids][]`): multi-select de checkboxes.
- **Sucursal** (`params[:sucursal_ids][]`): multi-select.
- **Estado del paquete** (`params[:estados][]`): multi-select de los ~15 estados.
- **Cliente** (`params[:cliente_id]`): autocomplete contra `/clientes/buscar`. Stimulus `client-autocomplete`. Pre-llena el input al recargar la página con el filtro activo.
- **Pre-Alerta** (`params[:pre_alerta_id]`): autocomplete contra `/pre_alertas/buscar`. Stimulus `pre-alerta-search`. Devuelve los paquetes vinculados vía `pre_alerta_paquetes`. Scope `Paquete.by_pre_alerta(id)` con `.distinct`.
- **Rango de fechas** (`fecha_desde` / `fecha_hasta`): aplica sobre `fecha_recibido_miami`.
- **Toggles rápidos**: `solo_facturados`, `incluir_facturados`, `sin_prealerta`, `incluir_3_12_meses`, `incluir_mas_1_ano`.

### UX y atajos de teclado
- **F2**: limpia todos los filtros y recarga (controller `f2-clear`).
- **Enter dentro de un input**: submitea el form (default del browser). Si el dropdown del autocomplete tiene un item resaltado, Enter selecciona ese item en lugar de submitear.
- **ArrowDown / ArrowUp**: navega entre opciones del dropdown (Cliente y Pre-Alerta).
- **Escape**: cierra el dropdown sin seleccionar.
- **Tab**: cierra el dropdown y pasa al siguiente campo.
- Submit con `data: { turbo: false }` + URL con anchor `#resultados` para que el browser scrollee a la tabla después de aplicar.
- Badge de "filtros activos" (esquina del summary) cuenta cuántos filtros están aplicados, incluyendo Cliente y Pre-Alerta.

### Endpoints reutilizados
- `GET /clientes/buscar?q=…` → JSON `[{id, codigo, nombre, notas_miami, categoria_precio}]`. Busca en código, nombre y apellido.
- `GET /pre_alertas/buscar?q=…` → JSON `[{id, numero, titulo, cliente, consolidado, estado}]`. Busca en `numero_documento`, `titulo`, `proveedor`, código y nombre del cliente.

### Archivos
- Vista: `app/views/paquetes/index.html.erb`.
- Controller: `app/controllers/paquetes_controller.rb` (acción `index`, método privado `apply_filters`).
- Stimulus: `app/javascript/controllers/client_autocomplete_controller.js`, `app/javascript/controllers/pre_alerta_search_controller.js`, `app/javascript/controllers/f2_clear_controller.js`.
- Modelo: `app/models/paquete.rb` (scopes `buscar`, `by_cliente`, `by_pre_alerta`, etc.).

---

## Etiquetar — sesión por tipo de envío, tercero y calculadora

Rediseño del mostrador `/etiquetar` (branch `feat/etiquetar-sesion-tercero-calc`). El operario etiqueta lotes de 10 a 1000+ paquetes del mismo tipo de envío, así que el flujo se optimizó para teclado y para elegir el tipo una sola vez por lote.

### Sesión por tipo de envío (server-side, sin tabla)
- Al entrar sin sesión activa, `/etiquetar` muestra un selector **"¿Qué tipo de envío vas a trabajar?"** con tarjetas ricas (ícono avión/camión, descripción del servicio y SLA) agrupadas en dos columnas (con / sin reempaque) — mismo patrón visual que el wizard de pre-alerta del cliente.
- Click en una tarjeta → `POST /etiquetar/sesion` (`iniciar_sesion`), que guarda `session[:etiquetar_tipo_envio_id]`. El tipo aplica a **todos** los paquetes del lote; ya **no** hay dropdown de tipo por paquete.
- Banner de **sesión activa coloreado por servicio** (acento del tipo) + botón **"Finalizar sesión de este tipo de envío"** → `DELETE /etiquetar/sesion` (`finalizar_sesion`).
- `create` toma `tipo_envio_id` de la sesión (no del form) y rechaza el guardado si no hay sesión activa (`before_action :require_tipo_envio_sesion`).

### Cliente tercero
- Campo **Tercero** (cliente final, FK `paquetes.tercero_id` → `Cliente`) debajo de Cliente. Partial compartido `shared/_tercero_field` que reusa el controller `tercero-search` + endpoint `/clientes/buscar`. `tercero_id` se permite en `paquete_params`.

### Orden del formulario
Tracking → Cliente → **Tercero** → Descripción → **Retener** (modal de motivos) → Carrier / Proveedor → Notas internas → **Peso / medidas / Cant. productos** (al final, junto a la calculadora).

### Calculadora 3-formas (solo display, no afluye en precio)
Una sola medida en **pulgadas** (alto × largo × ancho) → tres representaciones en vivo:
- **USA → HN · libra o volumen** ("la más común"): `VLbs = pulg³ / 166`, redondeo a ½ libra con umbrales **.10 / .60** (frac < .10 baja, .10–.59 → .50, ≥ .60 sube); **peso a cobrar = max(peso real, VLbs)**.
- **USA → HN · pie³** (informativo): `pulg³ / 1728`, **ceil** a entero.
- **China → HN · m³** (informativo): `pulg³ × 16.387064 / 1_000_000`, **ceil a 2 decimales**.

Fuente de verdad testeada: `VolumetricoCalculator` (PORO) con espejo en el Stimulus `calc-volumetrico`. **No** modifica `peso_cobrar` / `peso_volumetrico`; el precio se sigue calculando en Pre-Factura.

### UX y atajos de teclado
- **Foco inicial en Tracking** al cargar (forzado en `connect`, porque `autofocus` no es confiable en navegación Turbo).
- Autocompletes (Cliente y Tercero): al desplegar resultados el **primer ítem queda resaltado**; **↓ / ↑** navegan, **Enter** selecciona (con `preventDefault`, no envía el form), **Esc** cierra, **Tab** cierra y avanza. Mismo patrón que los filtros de `/paquetes`.
- **F2** limpiar · **F3** tracking secundario · **F8** guardar · **F9** guardar + imprimir (modal de cajas).

### Presentación de tipos de envío (compartida con pre-alerta)
- `TipoEnvioPresentationHelper`: descripciones canónicas v4 + acento por código (`text`/`icon_bg`/`bg`/`ring`) + ícono por modalidad (avión/camión).
- `shared/_tipo_envio_card` renderiza la tarjeta (ícono + nombre + descripción + SLA, opcional precio/badge). Flags `show_precio` / `show_badge` (default `true`); `/etiquetar` los apaga, el wizard del cliente los deja en `true`.
- Reusado por `app/views/cuenta/pre_alertas/new.html.erb` (paso 1) y por el selector de `/etiquetar`.

### Endpoints
- `POST /etiquetar/sesion` → `EtiquetarController#iniciar_sesion` (`iniciar_sesion_etiquetar_path`).
- `DELETE /etiquetar/sesion` → `EtiquetarController#finalizar_sesion` (`finalizar_sesion_etiquetar_path`).

### Archivos
- Controller: `app/controllers/etiquetar_controller.rb`.
- Vistas: `app/views/etiquetar/index.html.erb`, `app/views/shared/_tercero_field.html.erb`, `app/views/shared/_tipo_envio_card.html.erb`, `app/views/cuenta/pre_alertas/new.html.erb` (refactor a partial compartido).
- Helper: `app/helpers/tipo_envio_presentation_helper.rb`.
- Servicio: `app/services/volumetrico_calculator.rb` (tests en `test/services/volumetrico_calculator_test.rb`).
- Stimulus: `app/javascript/controllers/etiquetar_controller.js`, `calc_volumetrico_controller.js`, `tercero_search_controller.js`.
- Rutas: `config/routes.rb`.
- Tests: `test/controllers/etiquetar_controller_test.rb`, `test/controllers/etiquetar_auto_link_test.rb`.

---

## Fase 10: Contexto operativo en captura (PR-9) — EN CURSO (Agosto 2026)

**Objetivo:** que el operario vea el contexto del cliente **mientras captura**, sin salirse de la pantalla. Nace de las dos hojas manuscritas de Yusef del 2026-08-01 (ver `docs/05` — Conversación 4).

| # | Tarea | Módulos | Estado |
|---|-------|---------|--------|
| 9.0 | Documentar taxonomía de notas + spec de la franja; corregir entradas obsoletas | docs | ✅ |
| 9.a | `Tarea` multi-ancla: `cliente_id`, `paquete_id` opcional, `departamento`, `origen`, `bloquea_avance` | 32 | ✅ |
| 9.b | Franja de contexto (Cliente + Tareas + 5 categorías de Notas) en `/etiquetar` y `/entrega_personal` | 6, 32 | ✅ |
| 9.c | Sonidos: `AudioContext` suspendido + preferencias por usuario + diálogo de prueba | 6 | ✅ |

**Entregable:** el digitador escanea y ve de inmediato el nombre del cliente, sus tareas pendientes con checkbox, y sus 5 tipos de notas.

**Dependencia:** Fase 1 (etiquetar) + Fase 5 (modelo `Tarea`) + PR-D2 (notas categorizadas) + PR-6 (entrega personal). Todas cumplidas.

### Cambios de modelo (PR-9.a)

`tareas` gana cinco columnas:

| Columna | Tipo | Para qué |
|---|---|---|
| `cliente_id` | FK nullable | Una tarea puede colgar del **cliente**, no solo del paquete (en `/etiquetar` el paquete aún no existe cuando el operario escanea) |
| `pre_alerta_paquete_id` | FK nullable | Idempotencia: evita duplicar la tarea cada vez que se re-guarda la pre-alerta |
| `departamento` | string | `miami` · `caja` · `honduras` · `sac`. `nil` = visible para todos |
| `origen` | string | `manual` · `pre_alerta` |
| `bloquea_avance` | boolean | Si la tarea abierta impide que el paquete avance de estado |

`paquete_id` pasa a **nullable**. Validación nueva: una tarea debe tener `cliente_id` **o** `paquete_id`.

### Reglas clave

- ~~**Las `instrucciones` de la pre-alerta se vuelven tareas.**~~ **Revertido en `PR-C7.41` (`C16-01`, 2026-08-25).** `PreAlertaPaquete` sincronizaba una `Tarea` (`origen: "pre_alerta"`, `departamento: "miami"`) cuando el campo tenía contenido; Yusef lo paró —*"el cliente no puede poner una tarea, solo nosotros"*—. Las instrucciones son **nota** (modal de `/etiquetar`, franja, ficha del paquete) y las tareas las crea solo el personal. Las abiertas de ese origen se borraron por migración; las realizadas quedan como evidencia, y `link_tracking!` todavía las reapunta al paquete físico.
- **`bloquea_avance` protege el pipeline.** `Paquete#no_advance_with_open_tareas` congela el avance de estado si hay tareas abiertas. La bandera nació para que las tareas auto-creadas desde `instrucciones` no trabaran `pre_alerta_estado → empacado`; esa auto-creación ya no existe y la bandera queda como control manual por tarea (las manuales nacen con `true`).
- **Al completar** se guarda `completado_por` + `completada_en` (ya existía en `Tarea#completar!`) y la tarea desaparece de la franja **para todos**. Reabrir solo desde `/paquetes/:id/tareas`.
- **Orden de las notas por departamento:** Miami → Caja → Honduras → SAC. Pre-Factura y Entrega comparten `notas_honduras` a propósito; no se les creó columna propia.
- **La franja es solo lectura.** Los campos de escritura siguen en el formulario.

### Sonidos (PR-9.c) — causa raíz de "no suena en Tegus"

`audio_controller.js` sintetiza los tonos con Web Audio API. Dos problemas, ambos corregidos:

1. **`AudioContext` suspendido.** Chrome lo crea en estado `suspended` hasta que hay un gesto del usuario, y `_getContext()` nunca llamaba `resume()`. Peor: el `try/catch` de `_playTone` **se tragaba el error sin loguear nada**, así que fallaba de forma invisible. Ahora se llama `resume()` y se desbloquea en el primer `pointerdown`/`keydown`, y los fallos se loguean con `console.warn`.
2. **Volumen.** Ganancia fija `0.3` con onda `sine` se perdía en el ruido de bodega. Ahora la onda es `square` (corta mejor el ruido de fondo) y el volumen es configurable.

Preferencias por usuario: `users.sonido_habilitado` + `users.sonido_volumen` (0-100, default 60), persistidas vía `SonidoPreferencesController` — mismo patrón que `tema` y `sidebar_position`. El control vive en un `<dialog>` que se abre desde el header de ambas pantallas, con botones para probar cada tono (que además sirven de gesto para desbloquear el audio).

### Deuda técnica saldada de paso

- `TareasController` **no tenía ninguna autorización** (`before_action` de rol ausente desde PR #66): cualquier usuario autenticado podía crear, editar o borrar tareas de cualquier paquete. Corregido en PR-9.a con `GESTION_ROLES` (crear/editar/borrar) y `EJECUCION_ROLES` (completar/iniciar). **Desde `PR-C7.47` (`C17-01`) crear es de `CREACION_ROLES` = los que ejecutan**; editar/borrar sigue en `GESTION_ROLES`. Queda en `RP-45` para que Yusef lo confirme.
- **`EntregaPersonalController#render_create_error` reventaba con un 500.** No recargaba `@sucursales_miami` y la vista hace `.any?` sobre él, así que cualquier error de validación producía `undefined method 'any?' for nil` en vez de mostrarle los errores al digitador. Salió a la luz al escribir el primer test de request de la pantalla.
- `clientes/show` mostraba solo `notas_miami` y `notas_honduras`; `notas_caja` y `notas_sac` eran editables pero invisibles. Ahora lista las 4, filtradas por área y en orden por departamento.
- Se agregó `test/controllers/entrega_personal_controller_test.rb` — PR-6a y PR-6b habían salido sin ninguna cobertura de request.

### Deuda técnica detectada, NO saldada aquí

- `paquetes.notas_al_cliente` ~~**nunca llega al cliente**~~ — desde `PR-C7.51` (`C18-06`) viaja en el correo de recibido (`PreAlertaMailer#paquete_recibido`, html y texto), que se manda cuando hay pre-alerta o «enviado según política». Sigue sin ir en PDF ni en el portal (no hay detalle de paquete): es lo que falta.
- **`Manifiesto#sucursal_origen` nunca se asigna** (ningún controller lo setea): la numeración anual `M<letra><año><000001>` de PR-D1.d está muerta y todos los manifiestos caen al formato legacy `MA-…`. Y el día que se use, dos sucursales con la misma inicial (MIA y una MEX) chocarían en `index_manifiestos_on_numero`. Detectado en el seguimiento de `C18-02` (2026-08-27); queda en `RP-46`.
- `db/schema.rb` es un archivo muerto: `config/application.rb:24` fija `schema_format = :sql`, así que el schema autoritativo es **`db/structure.sql`**. El `schema.rb` quedó congelado en abril y confunde a quien lo lea; conviene borrarlo.
- `test/system/` está vacío, así que nada del comportamiento Stimulus (F-keys, sonidos, modales, el checkbox de la franja) tiene cobertura automatizada.
- `rubocop` reporta ~136 ofensas preexistentes en el repo y no corre en CI (el workflow solo ejecuta `rails test`).

---

## Fase 11: Tarifas y cálculo de cobro (PR-10) — EN CURSO (Agosto 2026)

**Objetivo:** que el sistema sepa cobrar. Hoy conoce el precio por libra y nada más: ni mínimos, ni escalones, ni excepciones, ni la moneda correcta. Nace de las 4 páginas manuscritas de Yusef y los 3 audios del 2026-08-02 (ver `docs/05` — Conversación 5).

| # | Tarea | Módulos | Estado |
|---|-------|---------|--------|
| 10.0 | Documentar tarifas, mínimos, flujo de Miami y spec de etiqueta | docs | ✅ |
| 10.a | Modelo `Tarifa` (cascada + escalones + mínimos) · fix de moneda · CRUD `/servicios` | 9, 11 | ✅ PR #203 |
| 10.b | Entrega Personal: peso/medidas/cálculo + valor a pagar en USD y LPS | 6 | ✅ |
| 10.c | Rutinas de UX en etiquetar (F4 tercero, búsquedas, modal, layout) | 6 | ✅ |
| 10.d | Etiqueta Dymo 2.25×1.25 con código de barras | 6, 7 | ✅ |
| 10.e | Separar Driver de Proveedor en Entrega Personal | 6 | ✅ |
| 10.f | Búsqueda por fragmentos de etiqueta rota + acentos | 11 | ✅ |
| 10.g | Sembrar la tabla de precios real (PROPUESTA 2026) | 9, 11 | ✅ |
| 10.h | El preview de paquetes muestra el precio que se va a cobrar | 3a | ✅ |

**Dependencia:** Fase 3a (billing) + PR-D6 (tarifas de recolecta y servicios extra). Cumplidas.

**Bloqueo:** ~~sembrar `tarifas` requiere la tabla de precios por categoría~~ — llegó el 2026-08-05 y se sembró en PR-10.g.

### Hallazgos de la exploración

| # | Hallazgo | Gravedad |
|---|---|---|
| 1 | **Los montos USD se guardan y muestran como Lempiras.** `build_from_paquetes` nunca setea `moneda` → queda `'LPS'` por default; los precios de `tipo_envios` son USD; `CurrencyAware#convertir` **jamás se invoca en todo el repo**; las vistas imprimen `"L. "` hardcodeado. Un CER de 10 lb sale "L. 45.00" cuando son $45 (≈ L.1,118 a la tasa vigente). | 🔴 |
| 2 | **No existe ningún mínimo de cobro.** Cero columnas, cero constantes, pese a estar especificados en `docs/05:503-538` desde abril. | 🔴 |
| 3 | **El cobro simbólico de prepagado en Miami se pierde.** `PreFacturaItem#calculate_subtotal_from_peso` corre en `before_validation` y sobrescribe el `$1.00` con `peso × 0 = 0`, porque `precio_libra: 0` cuenta como *present*. Cero tests lo cubren — PR-6b salió sin cobertura. | 🔴 |
| 4 | **`CategoriaPrecio` colapsa 5 servicios en 2 modalidades** (`precio_libra_aereo` / `precio_libra_maritimo`). Un cliente con categoría paga lo mismo en EXPRESS que en CER. Además `precio_volumen` es una columna muerta que ningún cálculo lee. | 🟡 |
| 5 | **`TipoEnvio` no tiene CRUD admin** — la "tabla de servicios" que Yusef pide. Los precios se sembraron a mano. | 🟡 |
| 6 | **`VolumetricoCalculator` está desconectado de `Paquete`.** La pantalla de etiquetar redondea a ½ libra (regla del spreadsheet de Yusef) pero `calculate_peso_volumetrico` factura con `.round(2)`. `8×9×9 = 648 pulg³` factura **3.90 lb** cuando debería ser **4.0**. | 🟡 |
| 7 | `ISV_RATE` duplicada en 5 modelos + `empresas.isv_rate` + `configuracions["iva_porcentaje"]`. Solo la constante calcula; `empresa.isv_rate` únicamente se imprime en los PDFs, así que cambiarla desalinea el documento del cálculo. | 🟡 |
| 8 | `servicios_extra.precio_incluye_isv` se ignora en `aplicar_cobros_automaticos_para` → **doble ISV** en servicios extra. | 🟡 |
| 9 | En el documento impreso, el encabezado **`Agent`** cae a `paquete.sucursal.nombre` cuando no hay agent (el caso normal) — el "San Pedro Soda". | 🟡 |
| 10 | La etiqueta **es** el Warehouse Receipt (carta 8.5×11 con T&C). Antes era térmica 4×6. **No hay código de barras ni QR en todo el repo** pese a que Yusef los da por existentes. | 🟡 |

### Modelo `Tarifa` (PR-10.a)

Una fila por combinación de reglas. Resolución en cascada — gana la más específica:

1. `cliente` + `tipo_envio` — *"el precio especial que está sobre todos los anteriores"*
2. `proveedor` + `tipo_envio` — promociones de Shein / Temu / doTERRA / Farmasi
3. `categoria_precio` + `tipo_envio`
4. `tipo_envio` solo — precio de lista

Dentro del nivel que gane, se elige el escalón `[desde_libras, hasta_libras)` que contiene el peso. Si existe una fila con `sucursal_id` que matchea, esa gana sobre la de sucursal nula (sobrecosto de transporte).

| Columna | Para qué |
|---|---|
| `precio_libra` · `moneda` | El precio del escalón |
| `desde_libras` · `hasta_libras` | Precio escalonado (`nil` en hasta = sin tope) |
| `minimo_monto` · `minimo_moneda` | Cobro mínimo. **Se guarda SIN ISV**: Yusef escribe 200, se guarda 173.91 |
| `minimo_libras` | Mínimo expresado en peso (CEM, CKM) |
| `aplica_minimo` | `false` para Exchange/Chain, que cobra por libra sin mínimo |
| `incremento_libras` | `0.5` = cobro por media libra |
| `cliente_id` · `proveedor_id` · `categoria_precio_id` · `sucursal_id` | Los ejes de la cascada |

`Tarifa#cobro_para(peso)` devuelve `{ subtotal, moneda, aplico_minimo }` aplicando, en orden: redondeo al `incremento_libras`, piso de `minimo_libras`, multiplicación por `precio_libra`, y piso de `minimo_monto` convertido a la moneda del cobro.

### Reglas de redondeo (ya estaban definidas, se aplican tal cual)

- **Peso volumétrico:** `VLbs = pulg³/166`, redondeo a **½ libra** con umbrales **.10/.60**; peso a cobrar = `max(peso real, VLbs)`. Vive en `VolumetricoCalculator`; PR-10.a hace que `Paquete` lo use.
- **Montos:** **half-up al segundo decimal** con `BigDecimal`, sobre el resultado final de cada línea. Regla del contador (Yusef, 2026-05-04).

### Decisiones confirmadas

- **Tasa de cambio fija**, la fija un admin → se **desactiva `ActualizarTasaCambioJob`** (hoy corre `every day at 6am` en producción y sobrescribiría la tasa manual).
- **El valor a pagar en Entrega Personal es solo display**, no se persiste.
- **El mínimo es por concepto** (flete, recolecta), no un mínimo global de factura.
- **Fuente única de ISV = `empresas.isv_rate`**; se eliminan las 5 constantes y la clave muerta de `configuracions`.
- La **cantidad de cajas se queda en el modal de F9** — Yusef revisó y confirmó.

### Etiqueta (PR-10.d)

Cuatro formatos distintos en la operación; **solo se rediseña el de ETIQUETAR**:

| Operación | Tamaño | Marca | Se pega |
|---|---|---|---|
| **ETIQUETAR** | **2.25 × 1.25 in** | Dymo | Una por paquete |
| MANIFIESTO | 4 × 6 in | FreeX | Una por caja o paquete |
| PRE-FACTURA (SPS) | 4 × 6 in | FreeX | Por paquete; puede llevar varios tracking |
| MANIFIESTO NACIONAL | 4 × 6 in | FreeX | Por fuera; varias pre-facturas |

Se separa la etiqueta del Warehouse Receipt. Código de barras **Code 128** del número de recepción vía `barby` + `chunky_png` como data-URI PNG (server-side, más confiable para impresión que una librería JS).

#### ✅ Qué campos van — resuelto (2026-08-06)

> "No creo cambiar el tamaño de la etiqueta. **Allí es letra pequeña unas y otras grandes.**" — Yusef

La pregunta era cuáles de los 11 campos recortar. La respuesta fue que **no se recorta ninguno**: van los 11 y lo que cambia es el cuerpo de letra. El tamaño de 2.25 × 1.25 in se queda.

| | Campos |
|---|---|
| **Grande** — se lee de lejos en la estantería | Número de recepción, tipo de envío, código y nombre del cliente, sucursal donde retira, n/N de paquetes |
| **Chico** — solo hace falta tenerlo a mano | Tracking principal y secundario, tercero, driver, ciudad del cliente, fecha y hora, iniciales |

#### La jerarquía, del mockup anotado (PR-10.d.2)

Yusef mandó su etiqueta vieja marcada campo por campo. Lo que hoy estaba chico
era lo que él quiere grande — el **tracking** sobre todo, que es lo que el
operario compara contra la caja que tiene en la mano.

Los tamaños viven en variables CSS (`--t1 … --t7`) en `layouts/etiqueta.html.erb`
para poder escalarlos de un solo lugar:

| | Campos |
|---|---|
| `--t1` 21pt | Tipo de envío — **lo más grande de la etiqueta** |
| `--t2` 12pt | Número de recepción |
| `--t3` 11pt | Código del cliente · n/N |
| `--t4` 9.5pt | Nombre del cliente · sucursal |
| `--t5` 7.5pt | Tracking y secundario |
| `--t6` 6.5pt | Fecha y hora · iniciales |
| `--t7` 6pt | Ubicación · tercero · driver |

**Lo que hace que quepa es el bloque de dos columnas de abajo**, que es la
estructura de su mockup: `C6` + `1/2` y la sucursal a la izquierda, el tipo de
envío enorme a la derecha. Así el elemento más grande no cuesta un renglón.

#### Que quepa es un test, no una cuenta

`test/system/etiqueta_cabe_test.rb` abre la etiqueta en **Chrome de verdad** y
compara `scrollHeight` contra `clientHeight` — el único modo de ver un recorte
de CSS. Con eso el ciclo es: fijar la jerarquía, medir, bajar los escalones si
no entra.

> ⚠️ **Dos trampas que costaron sangre acá:**
>
> 1. La primera versión del test **no tenía dientes**: pasaba aun con `--t1` en
>    40pt. Los hijos de un flex se **encogen** por defecto, así que en vez de
>    desbordar se comprimían y el texto se recortaba *adentro* de cada caja —
>    `scrollHeight` nunca crecía. Se arregló con `.etq > * { flex: 0 0 auto; }`,
>    que además es lo correcto para la impresión.
> 2. Con la medición ya funcionando, la configuración que yo había calculado a
>    mano en el turno anterior **no cabía** (121px contra 120px disponibles).
>
> Holgura real hoy: **16px de 120** con todos los campos llenos.

#### Dos cosas que salieron de mirar la etiqueta renderizada

- **El tipo de envío se abrevia a 3 letras.** El mockup dice `EXP`, no
  `EXPRESS`. No es cosmético: completo se come más de la mitad del ancho y deja
  la sucursal en **`SAN PED…`** — el "¿qué es San Pedro Soda?" reapareciendo.
- **La fecha no se encoge.** El driver le estaba robando el ancho y salía
  `27-Jul-2026 …` sin la hora. En la jerarquía de Yusef la fecha está por
  encima del driver, que ni figura en su mockup; ahora el que se recorta es el
  driver.

Lo que ningún test cubre: **que el código de barras siga escaneando**. Está en
0.20 in, que es el piso práctico para escáneres de mano. Eso se prueba
imprimiendo.

#### 🔴 La etiqueta no se usaba en ningún lado — PR-10.d.3

Jorge vio `/label` en la aplicación y pidió que dijera `etiqueta`. Buscando de
dónde salía apareció algo más grande: **`/label` no es la etiqueta, es el
Warehouse Receipt**, y la etiqueta Dymo que rediseñamos **solo era alcanzable
desde `/etiquetar` con F9**. Ningún otro camino la imprimía.

| Dónde | Decía | Imprimía |
|---|---|---|
| Icono de impresora del listado | `title: "Imprimir etiqueta"` | Warehouse Receipt |
| `#reimprimir_etiquetas` (paquete no dividido) | — | Warehouse Receipt |
| "Solo esta" en el modal de cajas | — | Warehouse Receipt |
| `#etiquetas_combinadas` | *"renderiza N warehouse receipts"* | N Warehouse Receipts |

O sea que **"Re-imprimir Etiquetas Miami"** sacaba hojas carta. Es exactamente
lo que Yusef reportó —*"aquí está tirando el warehouse, no la etiqueta"*— y que
solo se había arreglado en `/etiquetar`.

**El rename va al revés de lo pedido, a propósito:** `/label` pasa a
`/warehouse_receipt`, no a `/etiqueta`. Renombrarlo a `etiqueta` habría dejado
la confusión fija para siempre. El helper ya se llamaba
`warehouse_receipt_helper.rb` con métodos `wr_*`, así que el nombre correcto ya
estaba establecido en el código; solo la ruta, la acción y las vistas venían del
legacy.

Los dos documentos siguen separados, como pidió Yusef: *"la etiqueta para la
caja, el Warehouse Receipt para el expediente"*. El WR conserva su vista, su
helper, sus términos y su botón en el detalle del paquete.

> Un detalle que costó: renombrar la acción sin tocar el `before_action
> :set_paquete, only: [...]` dejó **todo el controlador en 404**, no solo el WR.
> Los tests lo agarraron al instante.

### Sembrado de precios reales (PR-10.g)

Los números viven en `lib/tarifas_propuesta_2026.rb` como constantes que espejan
la hoja de Yusef, y se aplican con:

```bash
bin/rails tarifas:sembrar_propuesta_2026
```

Tarea aparte y no dentro de `db/seeds.rb` (aunque el seed también la llama)
porque los precios cambian con el negocio y `seeds` se corre entero: una
corrección de precios tiene que poder aplicarse sola. Es idempotente — la llave
natural es `(tipo_envio, categoría, sucursal, desde_libras)` y las filas se
actualizan en vez de duplicarse.

Qué siembra: 7 categorías nuevas (`Clientes Amigos`, `doTERRA / Farmasi`,
`Personal CEC`, `Shein`, `Sin Cobro Mínimo`, `Familia`, `Revendedores`), ~44
tarifas entre precio de lista escalonado, precios por categoría y los tres
sobrecostos de Tegucigalpa. `Regular` y `VIP` **no se tocan** — no están en el
archivo de Yusef y tienen 8 clientes colgando.

De paso sincroniza `tipo_envios.precio_libra`, que es el fallback cuando no hay
tarifa cargada y había quedado desalineado (**EXPRESS 8.00 → 7.50**, **CKM 1.50
→ 1.90**). Un fallback que cobra distinto que la tarifa es peor que no tenerlo.

El detalle de la tabla, las decisiones de lectura del archivo y lo que sigue
abierto están en `docs/05` — "La tabla de precios recibida (2026-08-05)".

### Deuda técnica que se salda de paso

- El cobro simbólico de prepagado en Miami (#3), hoy silenciosamente en $0.
- `Paquete` pasa a usar `VolumetricoCalculator` (#6) — la pantalla y la factura dejan de discrepar.
- `ISV_RATE` a fuente única (#7) y `precio_incluye_isv` respetado (#8).
- En `/entrega_personal`, **F2 y F9 se disparan dos veces** (`ButtonComponent` emite `data-shortcut` y el Stimulus también escucha en `document`) — el segundo `showModal()` sobre un `<dialog>` abierto tira `InvalidStateError`.
- `Cliente.buscar` no encuentra `"Juan Perez"` (hace `OR` sobre columnas sueltas, nunca concatena nombre y apellido) ni normaliza los ceros del código.

---

## Fase 12: Manifiesto de punta a punta — ✅ COMPLETA (serie PR-M)

> **2026-08-30 · la serie `PR-M`, completa.** El diseño de la Conversación 21
> se construyó en nueve PRs que mergearon solos, todos el mismo día.

| PR | Qué | Ítem de `docs/05` | Estado |
|---|---|---|---|
| `PR-M1` | El portal de catálogos del manifiesto — empresas, tipos del proveedor, consignatarios y tamaños | `C21-08` | ✅ #367 |
| `PR-M2` | El encabezado que Yusef anotó a mano, y el número que por fin lleva el año (`MM2026000001`) | `C21-02`, `C21-03`, `C21-11` | ✅ #368 |
| `PR-M3` | Las casas del manifiesto — tamaño, medidas editables y volumen ÷166 | `C21-04` | ✅ #369 |
| `PR-M4` | La etiqueta 4×6 del bulto, con el número de manifiesto que faltaba | `C21-05` | ✅ #370 |
| `PR-M5` | El pip pip pip — escanear el paquete al meterlo a la caja | `C21-01` | ✅ #371 |
| `PR-M6` | Finalizar manda todo a ENVIADO, y el manifiesto queda bloqueado | `C21-06` | ✅ #372 |
| `PR-M7` | Recibir la carga en Honduras escaneando cajas | `C21-07` | ✅ #373 |
| `PR-M8` | La pre-factura se amarra al manifiesto | `C21-10` | ✅ |
| `PR-M9` | El documento impreso — encabezado, teléfono, encargado y letra más grande | `C21-09` | ✅ |

**Lo que se cerró de paso:** `RP-30` (aduana ya tiene pantalla y quién escriba el
estado — `PR-M7` es el **primer escritor de `en_aduana` en todo el sistema**),
`RP-46(c)` (manifiesto por sucursal con su número anual), `RP-53` y `RP-55`
(los dos los contestó Jorge).

**Lo que sigue siendo hueco:** la **bodega en Honduras**. Nadie escribe
`disponible_entrega`, así que la carga que entra por manifiesto se queda en
`en_aduana` hasta que la pre-factura la mueve. `PR-M8` ensanchó
`Paquete.facturables` para que eso funcione; el módulo de bodega sigue sin
construirse y `lib/procesos_pdf.rb` lo dibuja con `existe: false`.

---

### El diseño original (Conversación 21)

> **2026-08-29 · la Conversación 21 la cerró.** Yusef dedicó una videollamada de
> 95 minutos con la pantalla compartida desde Miami, mandó **seis fotos** —dos de
> ellas el manifiesto impreso del legacy **anotado campo por campo**— y Jorge sumó
> la captura de la pantalla vieja. El detalle está en `docs/05`, `C21-01` a
> `C21-11`. Lo de abajo es el diseño previo, que sigue siendo correcto: la
> Conversación 21 lo **completa**, no lo contradice.

**Lo que agrega la Conversación 21**, en corto: crear el manifiesto **primero** y
sacar de ahí las pre-etiquetas de los bultos; el encabezado con quién llena cada
campo (Miami vs SPS) y los rótulos explícitos «tipo de envío del proveedor» vs
«nuestro»; el tipo de envío nuestro en selección múltiple obligatoria; los diez
tamaños de caja con medidas editables (*«EH cortada»*) y volumen ÷166; la etiqueta
**4×6** del bulto —que necesita el número de manifiesto y es un **formato nuevo**,
porque la plantilla actual es singleton y topa en 3 pulgadas de alto—; el bloqueo
del manifiesto al finalizar; la **pantalla de recibir carga** en Honduras (la hacen
los de pre-factura, escanean cajas, 5-10 por vez); un **CRUD único** para los
catálogos; y el amarre de la **pre-factura al manifiesto**, no a la guía.

**El enganche, verificado en el código (2026-08-30):** `Manifiesto`,
`ManifiestoCounter` y `EmpresaManifiesto` funcionan desde la Fase 1. El enum ya
tiene `en_aduana` y `recibido` y `fecha_aduana` ya es columna — **la mitad de
recepción entra sin migración**. Está muerto: `sucursal_origen` (nadie lo asigna →
la numeración anual `MM2026000001` nunca corre, `RP-46`), `TamanoCaja` y
`Consignatario` (tablas vacías, sin pantallas), y el estado `empacado`. **Sigue
faltando la entidad «caja empacada»**, que es de la que cuelga todo.

---

### El diseño previo (Conversación 5) — sigue vigente

**No se construye en PR-10.** Yusef pidió explícitamente dejarla diseñada:

> "No quiero que el sistema se complique, pero **quiero que lo planifiquemos aunque lo dejemos por fuera — que quede ya planificado y le dejes los accesos, los campos para amarrarlo**."

**El diseño que describió:**
1. Se crea una **pre-etiqueta de caja** con tipo de servicio y tamaño de caja (`E`, `mini D`, `mini D doble` — el modelo `TamanoCaja` ya existe), editable después por si la cortan.
2. El operario escanea cada paquete con un escáner inalámbrico al meterlo a la caja.
3. **Si el tipo de servicio no concuerda con el de la caja, pita** — es el escenario ya anotado de manifiesto interno con sonidos por tipo de envío.
4. Al crear el manifiesto se **jalan las cajas empacadas**, no paquetes sueltos.
5. Botón de "omitir" para no trabar la operación cuando algo no cuadra.

**Motivación:** hoy no saben si una carga salió, y por eso le dan al cliente rangos de "entre lunes y viernes". Yusef está reorganizando las salidas (lunes, jueves y viernes después de mediodía) para acotar eso.

**Enganche existente:** `Manifiesto`, `TamanoCaja` y `EmpresaManifiesto` ya están en el modelo. Falta la entidad de "caja empacada" entre `Paquete` y `Manifiesto`.

### La otra mitad: recibir el manifiesto en Honduras (Conversación 7)

La Fase 12 tenía dibujada la salida —empacar en Miami— pero no la entrada. La
Conversación 7 la completó, y de paso cerró `RP-30`: el hueco entre *manifiesto*
y *aduana*, donde hoy alguien entra a la ficha del paquete y cambia el estado a
mano, se llena escaneando.

**El circuito** (`A7-03`…`A7-08`):

1. Cada caja del manifiesto lleva **su propio código único** — QR o barras. Ojo:
   no es el código de la etiqueta del paquete, que es el warehouse receipt.
2. Se escanea **primero la hoja del manifiesto**, y eso lo "activa": habilita el
   escaneo de las cajas y pasa los paquetes a *en aduana*.
3. Se escanean **las cajas, no los paquetes** — el manifiesto internacional se
   cuadra a nivel de caja.
4. **No bloquea.** Jorge preguntó explícitamente qué tan dura era la regla y
   Yusef eligió que avise: al finalizar enumera lo que falta (*"falta la 2 de 3,
   falta la 8 de 10"*) y ofrece **seguir escaneando** o **marcar como recibido
   con las pendientes**. El pendiente queda consultable para el admin.
5. Si falta una caja del manifiesto internacional, además **manda correo**.

**El manifiesto interno de sucursal** funciona igual (`A7-07`). Llega a
Tegucigalpa entre las 9:30 y las 15:00, trae de 1 a ~50 paquetes, y al escanearlo
**notifica a todos los clientes de golpe** — pero con una **ventana de espera de
30 a 60 min** (`RP-32`), porque en la práctica escanean el manifiesto y después
siguen cuadrando paquete por paquete. Push y correo siempre; WhatsApp **o** SMS,
nunca los dos.

**Depende de** los estados nuevos (`A7-09`, `A7-10`) y del sonido OK/ERROR por
tipo de envío, que ya tiene su fuente en `lib/sonidos_de_error.rb`.

---

## Fase 13: Precio bloqueado en pre-factura + autorización de supervisor — EN CURSO (Agosto 2026)

| # | Tarea | Estado |
|---|-------|--------|
| 13.a | Notas de débito/crédito por `Tarifa.resolver` + el mínimo sobrevive a facturar | ✅ |
| 13.b | Descuento como campo propio (monto o %, ISV sobre el neto) | ✅ |
| 13.c | Rol `supervisor_sac` + PIN de 4 dígitos | ✅ |
| 13.d | Autorización por línea y el candado | ✅ |
| 13.e | Emitir notas de débito/crédito pide PIN + cuatro ojos | ✅ |

Sale de la aclaración de Yusef del 2026-08-05 sobre
la nota `TARIFA EDITABLE CON AUTORIZACION DE SUPERVISOR O JEFE` que repite en
casi todas las filas de su tabla de precios. Al principio se leyó como una
descripción de su proceso interno; **es una función del sistema**:

> "Ahí, como es el área de pre-facturación, no hemos entrado ahí, en donde entra ya ciertas cosas que los supervisores o jefes son los que [autorizan el] cambio. Por eso queremos que el área de los precios estén establecidos, listo. **No hay nada más, no se puede hacer más si está todo preestablecido.** Ahora, si lo quieren modificar, ellos tienen que pedir autorización — ahí es donde entra un jefe, un supervisor, y ahí es donde llega y **pone un código especial de él**."

**El circuito:**

1. Los precios se cargan una vez en `/servicios`, solo admin. ✅ ya está (PR-10.a + PR-10.g).
2. **En la pre-factura el precio sale bloqueado.** El cajero no lo toca.
3. Si hay que cambiarlo, pide autorización.
4. El supervisor o jefe **teclea su código** en la pantalla y eso destraba esa línea.
5. Queda el registro de quién autorizó qué y por qué.

Lo importante es el **punto 2**: el precio bloqueado por defecto es el
requisito. La autorización es la excepción, no al revés.

### ✅ El candado — PR-13.d

`pre_factura_params` permitía `precio_libra`, `peso_cobrar`, `subtotal` y
`_destroy`, y la vista los exponía como inputs sueltos: cualquiera con acceso a
pre-facturas cambiaba el monto sin dejar dicho por qué. Ahora **solo permite
`concepto`** (la descripción, no el monto), y los cinco campos que mueven plata
van por `AutorizacionesLineaController`.

Aplica **a todos, incluido el admin**. Si el admin puede editar suelto, el
registro tiene un agujero y deja de servir como prueba.

#### Autorizar y cambiar son el mismo acto

No existe un modo "desbloqueado". El supervisor está parado en el mostrador, así
que el modal recoge **el cambio y el PIN juntos** y `AutorizacionLinea.aplicar!`
hace las dos cosas en una transacción o ninguna.

La alternativa —el PIN abre una ventana de edición— tiene dos problemas: el
registro puede quedar desalineado del cambio, y la ventana queda abierta cuando
el supervisor ya se fue.

#### El registro

`autorizaciones_linea` guarda quién autorizó, quién pidió, la acción, el valor
**anterior y nuevo**, el motivo (obligatorio) y un snapshot del `concepto`.

- `pre_factura_id` va aparte de `pre_factura_item_id` porque una de las acciones
  es eliminar la línea: el item desaparece (`nullify`) y el registro sobrevive.
- `valor_nuevo` se lee del item **después** de aplicar, no del formulario: con un
  descuento capturado como "10%" lo que hay que registrar es el monto que
  resultó (L.111.83). Guardar el 10 haría que el total de la bitácora sumara
  porcentajes con lempiras.

#### El límite de intentos

`rate_limit to: 5, within: 5.minutes`, **por supervisor y no por IP** (que es el
default de Rails): en un mostrador todos comparten la IP, así que por IP el
primero en equivocarse dejaría afuera a los demás y el cajero legítimo se
comería el bloqueo.

> ⚠️ El entorno de test corría con `cache_store = :null_store`, y `rate_limit`
> cuenta ahí — o sea que **un límite de intentos habría pasado los tests sin
> existir**. Se le puso `config.action_controller.cache_store = :memory_store`
> al entorno de test, y `test_helper` lo limpia antes de cada test: el contador
> vive en el proceso, y el `rate_limit` del login de `SessionsController` es por
> IP, así que sin limpiarlo los tests se caían solos a partir del undécimo.

### ✅ Las notas de débito y crédito — PR-13.e

**El control va en otro lado, y a propósito.** La nota **no saca su monto de la
tabla de tarifas** — ajustar a mano es su propósito. Trabar cada línea sería
trabar justamente lo que el documento viene a hacer.

Así que el PIN se pide **al emitir**, que es el momento en que el saldo del
cliente cambia. Antes de eso la nota vive en `creado` y no mueve plata.

| | |
|---|---|
| Pre-factura | El precio viene de una tarifa → candado **por línea** |
| Nota | El monto es manual por diseño → PIN **al emitir** |

#### Cuatro ojos

Quien arma la nota **no puede emitirla él mismo**; el dropdown ni lo ofrece. Es
el control clásico contra el autoservicio, y acá pesa más que en la pre-factura:
una nota de crédito es plata que se le devuelve al cliente, y un `cajero` puede
crear notas de débito.

> La validación va como `validate` y no como un chequeo suelto antes de
> `valid?`: **`valid?` limpia los errores**, así que un `errors.add` previo se
> perdía en silencio y la nota se emitía igual. Lo encontró el test.

#### Una sola bitácora

`AutorizacionLinea` pasó a ser `Autorizacion` con `documento` polimórfico
(`PreFactura` · `NotaCredito` · `NotaDebito`). Es el mismo hecho de negocio —
plata que se movió sin una tarifa detrás— y en dos pantallas separadas nadie
sumaría las dos.

La bitácora muestra aparte el **total devuelto por notas de crédito**, que se
lee distinto del descuento.

> `has_many :autorizaciones` necesitó una regla de inflexión: el inflector
> inglés singulariza a `Autorizacione`. El repo ya resuelve así el resto de los
> nombres en español.

#### La bitácora — `/autorizaciones`

Qué se autorizó, quién, contra qué valor y por qué, con el **total descontado**
del período arriba. La ven los mismos roles que pueden autorizar.

Sin una pantalla donde mirarlo, todo el mecanismo es solo fricción en el
mostrador: se registra pero nadie lo lee.

### El descuento como dato propio (PR-13.b)

Hasta acá un descuento se hacía **bajándole el precio a la línea**, así que era
invisible: la factura salía con un precio más bajo y nada decía que hubo
descuento, ni de cuánto, ni quién lo dio. La vista de pre-factura hasta lo
documentaba — el input de subtotal tenía el tooltip *"Editable para descuentos
autorizados"*.

Mal se puede autorizar con un PIN algo que después no queda registrado.

**Columnas.** `descuento_monto` (autoritativo — es el que suma y el que se
imprime), `descuento_porcentaje` (nullable, solo si se capturó como %, para
poder imprimir "Descuento (10%)") y `descuento_motivo`, en
`pre_factura_items` y `venta_items`. Más `descuento` acumulado en `pre_facturas`
y `ventas` para el bloque de totales.

Guardar el monto calculado en vez de derivarlo del % en cada lectura evita un
segundo redondeo sobre un número que ya está en la factura. Y el descuento
**no se recalcula** si después cambia el subtotal: uno que se mueve solo después
de que un supervisor lo autorizó deja de ser lo que se autorizó.

**El ISV va sobre el neto** — confirmado por Jorge. Es el orden contable normal:
el impuesto se calcula sobre lo que realmente se le cobra al cliente.

```
Subtotal          L. 1,118.30
Descuento (10%)  -L.   111.83
Importe gravado   L. 1,006.47
ISV (15%)         L.   150.97
Total             L. 1,157.44
```

Sobre el bruto el ISV daría L.167.75 — L.16.78 de más al cliente.

El documento muestra el **importe gravado** siempre que haya descuento: sin esa
línea no hay cómo verificar de dónde sale el ISV.

`PreFactura#calculate_totals` y `Venta#calculate_totals` son gemelos y cambiaron
igual. Con `descuento` en 0 el resultado es idéntico al anterior — hay un test
que lo fija, porque era el riesgo real de tocar esa función.

### ✅ El mínimo no sobrevivía a facturar — arreglado en PR-13.a

🔴 **El peor de los que aparecieron, y no estaba planificado.**

PR-10.a le puso a `pre_factura_items` la bandera `minimo_aplicado` para que su
`before_validation` no pisara el subtotal cuando este no sale de peso × precio.
**Los otros tres documentos de cobro tienen el mismo callback y nunca
recibieron el guard**: `VentaItem`, `NotaCreditoItem` y `NotaDebitoItem`.

Como `PreFactura#facturar!` copia las líneas a `venta_items`, el callback de
`VentaItem` recalculaba y pisaba el monto en el documento que **efectivamente
cobra**:

| Caso | Pre-factura | Factura emitida |
|---|---|---|
| CER de 0.5 lb (mínimo de servicio) | L.173.91 | **L.55.92** |
| Prepagado en Miami (simbólico $1) | L.24.85 | **L.0.00** |

O sea que el arreglo del simbólico de prepagado en PR-10.a quedó a medias — del
lado de la pre-factura, no del de la venta.

Mientras las tarifas eran el backfill plano de PR-10.a no había ningún mínimo
cargado y esto no se notaba. Con la tabla real de Yusef (PR-10.g) **todo paquete
chico se facturaba de menos**.

Arreglado con la columna en las tres tablas, el mismo guard en los tres modelos
y `facturar!` propagando la bandera. Tests en
`test/models/notas_precio_real_test.rb`, verificados quitando el guard: 3
fallan.

### ✅ Las notas usaban la tabla de precios vieja — arreglado en PR-13.a

`NotaCredito.build_from_paquetes` y `NotaDebito.build_from_paquetes` armaban sus
líneas con la cadena que PR-10.a vino a reemplazar
(`categoria_precio.precio_para || tipo_envio.precio_libra`): sin mínimos, sin
escalones y **sin convertir a Lempiras**, pero sus documentos se imprimen en
Lempiras.

No era teórico: la nota de débito **se auto-genera** en `facturar!` para todo
paquete con `solicito_cambio_servicio`.

Ahora las dos pasan por `CotizadorFlete`, vía el concern
`app/models/concerns/lineas_de_flete.rb`. Con eso se cierra la cadena vieja: los
únicos `precio_para(` que quedan son el fallback documentado de `PreFactura` y
`CotizadorFlete`, que sí convierten.

### ✅ El preview de paquetes mostraba otro precio — arreglado en PR-10.h

La pantalla de selección de paquetes (`/pre_facturas/new`) y el JSON de
`PreFacturasController#facturables` **no pasaban por `Tarifa.resolver`**: seguían
con la cadena vieja `categoria_precio.precio_para || tipo_envio.precio_libra`,
sin mínimos, sin escalones y **sin convertir a Lempiras** — pero la vista lo
imprimía con "L." adelante. Es el mismo bug de moneda que PR-10.a arregló en
`build_from_paquetes`, en el camino que quedó afuera.

Mientras las tarifas eran un backfill plano la diferencia no se notaba. Con los
precios reales de PR-10.g se volvió grande: un CER de 0.5 lb mostraba **$2.25**
rotulado como Lempiras y la pre-factura cobraba **L.173.91**. Contradice de
frente el "los precios están preestablecidos" — el cajero veía un número y el
sistema cobraba otro.

Se arregló llamando a `CotizadorFlete`, el mismo servicio que usa
`/entrega_personal`, desde un único `#cotizar` que alimenta la vista y el JSON.
La pantalla ahora marca además cuándo el monto salió del mínimo del servicio.

El guard está en `test/controllers/pre_factura_preview_precio_test.rb`, y no
compara contra números escritos a mano sino contra lo que devuelve
`PreFactura.build_from_paquetes` para el mismo paquete — que es la invariante
que se rompió. Verificado reintroduciendo el cálculo viejo: 3 de los 4 tests
fallan.

### Especificación (respondida por Yusef, 2026-08-05)

| Pregunta | Respuesta |
|---|---|
| ¿Cómo es el código? | **PIN de 4 dígitos**, aparte de la contraseña con la que el supervisor entra al sistema |
| ¿Qué destraba? | **Todo**: precio, descuento, quitar líneas y cambiar el peso a cobrar |
| ¿Alcance? | **Por línea.** No se autoriza la pre-factura entera |
| ¿Quién autoriza? | `admin`, `supervisor_prefactura`, `supervisor_caja` y **`supervisor_sac`** |

#### ✅ El rol `supervisor_sac` y el PIN — PR-13.c

`sac` ya existía (el agente de servicio al cliente); lo que faltaba era **su
supervisor**, que Yusef cuenta también como jefe. Ve lo mismo que su equipo
(`:marketing` y las notas de SAC) y entra al dashboard como los otros
supervisores.

```ruby
has_secure_password :pin, validations: false          # → pin_digest, authenticate_pin
has_paper_trail skip: %i[password_digest pin_digest]

validates :pin, format: { with: /\A\d{4}\z/ }, confirmation: true, if: -> { pin.present? }

ROLES_AUTORIZANTES = %w[admin supervisor_prefactura supervisor_caja supervisor_sac].freeze
scope :autorizantes, -> { activos.where(rol: ROLES_AUTORIZANTES).where.not(pin_digest: nil) }

def puede_autorizar?
  activo? && pin_digest.present? && rol.in?(ROLES_AUTORIZANTES)
end
```

Columnas en `users`: `pin_digest`, `pin_cambiado_at`. `:pin` va a
`filter_parameters` — cuatro dígitos que mueven plata no pueden quedar en el log.

**Autorizar no es un permiso de pantalla**, y por eso `puede_autorizar?` no pasa
por `can_access?`. El supervisor **nunca inicia sesión** para esto: el cajero
sigue logueado y el supervisor solo teclea cuatro dígitos parado en el mostrador.
Pedirle que cierre y abra sesión con el cliente enfrente no es viable.

**El PIN y la contraseña son credenciales distintas**: el PIN no sirve para
entrar al sistema y la contraseña no sirve para autorizar. Hay un test que lo
fija, porque es fácil que alguien "simplifique" eso más adelante.

**El circuito del PIN inicial:**

- El admin lo asigna en `/users` (`app/views/users/_form.html.erb`).
- El supervisor lo cambia en `/mi_pin/edit` (`PinsController`), **dando el
  actual**: si alguien encuentra una sesión abierta no debería poder dejar al
  supervisor afuera y quedarse autorizando en su nombre.
- Nadie se auto-asigna el primero; ese lo pone el admin.
- Si el admin lo reasigna, `pin_cambiado_at` vuelve a nil.

**No se bloquea autorizar con el PIN inicial** — trabar el mostrador por eso es
peor que el riesgo. En su lugar hay un aviso en `/mi_pin`, el link del sidebar
cambia a "Cambiá tu PIN", y `/users` marca "PIN sin cambiar" para que el admin
insista. Sin eso el admin conoce el PIN con el que otro autoriza, y el registro
de "quién autorizó" deja de probar nada.

El seed le pone PIN a los cuatro roles autorizantes (`1111` pre-factura, `2222`
SAC, `3333` caja) para poder probar el flujo.

#### Lo que implica el "por línea"

Que el PIN no abre una sesión de edición: **autoriza una línea concreta y queda
pegado a ella**. Si el cajero toca otra línea, se pide de nuevo. Eso hace que el
registro sea útil — se sabe qué línea se cambió, quién la autorizó y contra qué
valor original.

Lo mínimo a guardar por línea autorizada: quién autorizó, cuándo, el valor
anterior y el motivo. El valor anterior importa porque el precio de la tarifa se
puede haber movido después, y sin ese dato la auditoría no reconstruye nada.

#### Las cuatro cosas que destraba

| Qué | Dónde está hoy |
|---|---|
| Precio | `pre_factura_items.precio_libra` |
| Peso a cobrar | `pre_factura_items.peso_cobrar` |
| Descuento | ✅ `pre_factura_items.descuento_monto` (PR-13.b) |
| Quitar líneas | `_destroy` en `pre_factura_items_attributes` |

#### Un PIN de 4 dígitos hay que tratarlo como credencial

Solo 10 000 combinaciones: se adivina en minutos a fuerza bruta. Va con `bcrypt`
y fuera del log (PR-13.c), y **el límite de intentos ya está puesto** en el
endpoint de autorización (PR-13.d): `rate_limit to: 5, within: 5.minutes` en
`app/controllers/autorizaciones_controller.rb`. Es por supervisor y no por IP,
porque en un mostrador todos comparten la IP y por IP el límite se lo comería el
cajero legítimo.

**Falta un caso**: pagos parciales y crédito también van a pedir PIN, y ese lo
pone el **supervisor de caja** — un rol distinto del de prefactura y del de
entrega (`A7-30`, Conversación 7).

Es el único punto de todo el sistema donde 4 dígitos habilitan cambiar plata.

### Enganche existente

- Los 9 roles y el concern `Authorization` (`require_role`, `can_access?`).
- `paper_trail` en `PreFactura` y `Tarifa` — falta el *motivo* y el *autorizante*.
- `PreFacturaItem#origen` ya distingue `automatico` de `manual`; una línea con
  precio autorizado sería un tercer origen.
- `SessionsController:5` ya usa `rate_limit` — mismo patrón para el PIN.
