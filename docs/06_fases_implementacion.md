# CEC — Fases de Implementacion

39 modulos · 37 modelos · 620 tests · Rails 8 + Hotwire + Tailwind CSS 4 + PostgreSQL 16

```
Pre-alerta → Recepcion Miami → Manifiesto → Pre-factura → Factura → Pago → Entrega
```

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

## Fase 5: Tareas, Fotos y Re-empaque (mejoras Miami)

**Objetivo:** Sistema de tareas para operaciones especiales + fotos.

| # | Tarea | Modulos |
|---|-------|---------|
| 5.1 | Modelo Tarea asociada a paquete (checklist operador) | 32 |
| 5.2 | Estados tarea: pendiente → en proceso → realizado | 32 |
| 5.3 | Paquete no avanza hasta completar todas sus tareas | 32 |
| 5.4 | Re-empaque como tarea/servicio: tracking de quien lo hizo | 2, 37 |
| 5.5 | Registro dimensiones antes/despues, calculo ahorro volumen | 37 |
| 5.6 | Fotos de paquetes: captura desde camaras de estacion (2 camaras) | 35 |
| 5.7 | Active Storage + S3: adjuntar fotos al paquete | 35 |
| 5.8 | Fotos en email de notificacion al cliente | 35 |

**Entregable:** Operaciones especiales en Miami sistematizadas.

**Dependencia:** Fase 1 (etiquetar) + Fase 2 (pre-alertas).

---

## Fase 6: Reportes, Dashboard y Configuraciones

**Objetivo:** Visibilidad completa del negocio + administracion.

| # | Tarea | Modulos |
|---|-------|---------|
| 6.1 | Dashboard admin con estadisticas (graficas, KPIs) | 30 |
| 6.2 | 12 reportes (por definir detalle de cada uno) | 29 |
| 6.3 | 22 catalogos de configuracion (CRUD para cada uno) | 28 |
| 6.4 | Costos de empresa (/Mantenimientos/) | 31 |
| 6.5 | Tasa de cambio LPS/USD configurable | 28 |
| 6.6 | Calculadora de costos mejorada (cliente) | 38 |
| 6.7 | Seguimiento publico de paquete (sin login) | 39 |

**Entregable:** Admin tiene control total, cliente tiene visibilidad.

**Dependencia:** Fases 1-4 (necesita datos reales para reportes).

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
Fase 5  ░░░░░░░░░░░░░░░░░░░░  Tareas + Fotos + Re-empaque (Miami)        ← SIGUIENTE
Fase 6  ░░░░░░░░░░░░░░░░░░░░  Reportes + Config + Dashboard
Fase 7  ░░░░░░░░░░░░░░░░░░░░  Marketing CRM
Fase 8  ░░░░░░░░░░░░░░░░░░░░  Inventario
```

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
