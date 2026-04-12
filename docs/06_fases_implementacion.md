# CEC — Fases de Implementacion

39 modulos, Rails 8 + Hotwire + Tailwind CSS 4 + PostgreSQL 16

```
Pre-alerta → Recepcion Miami → Manifiesto → Pre-factura → Factura → Pago → Entrega
```

---

## Fase 0: Fundacion (Rails scaffold + auth + deploy)

**Objetivo:** App corriendo en staging con login, roles y layout base.

| # | Tarea | Modulos |
|---|-------|---------|
| 0.1 | Rails 8 new + PostgreSQL + Tailwind 4 + Hotwire | — |
| 0.2 | Autenticacion (Rails 8 generator) + sesiones | 1 |
| 0.3 | Modelo User con 9 roles + enum + ubicacion (miami/honduras) | 2 |
| 0.4 | Sistema de autorizacion por rol (qué ve cada quien) | 2 |
| 0.5 | Layout responsive: sidebar admin + sidebar cliente (Mi Cuenta) | 3, 4 |
| 0.6 | Plantilla base reutilizable (busqueda + filtros + tabla + paginacion) | 8 (patron UI) |
| 0.7 | Seeds: tipos envio, carriers, empresas manifiesto, categorias precio, admin user | Config |
| 0.8 | Deploy a Render staging + CI/CD GitHub Actions | Infra |
| 0.9 | Modelo Cliente + CRUD basico | 11 |

**Entregable:** Login funcional, 2 portales (admin/cliente), layout responsive, deploy automatico.

**Dependencia:** Ninguna — se puede empezar ya.

---

## Fase 1: Flujo Miami (el core del negocio)

**Objetivo:** Digitadores en Miami pueden etiquetar paquetes y armar manifiestos.

| # | Tarea | Modulos |
|---|-------|---------|
| 1.1 | Modelo Paquete con estados (enum), tracking, dimensiones | 7 |
| 1.2 | Pantalla Etiquetar/Digitar — formulario con 18 campos, atajos F2/F8/F9 | 6 |
| 1.3 | Autocomplete de cliente por codigo (C5344) con Turbo | 6 |
| 1.4 | Notas del cliente por ubicacion (Miami/Honduras) visibles al etiquetar | 34 |
| 1.5 | Sonidos: confirmacion al guardar, error en duplicados, alerta en notas | 33 |
| 1.6 | Deteccion de tracking duplicado/reciclado con historial | 36 |
| 1.7 | Soporte 1 tracking → multiples cajas (caso DHL) | 36 |
| 1.8 | Impresion de etiquetas (F9) | 6 |
| 1.9 | Modelo Manifiesto + CRUD: crear, agregar paquetes, enviar | 8 |
| 1.10 | Vista Todos los Paquetes con filtros avanzados + leyenda colores | 7 |

**Entregable:** Miami operativo — digitadores etiquetan, supervisores crean manifiestos.

**Dependencia:** Fase 0 completa.

---

## Fase 2: Pre-Alertas (cliente + admin)

**Objetivo:** Clientes crean pre-alertas desde Mi Cuenta, admin las gestiona.

| # | Tarea | Modulos |
|---|-------|---------|
| 2.1 | Portal Cliente (Mi Cuenta): dashboard con quick links, sidebar | 3 |
| 2.2 | Modelo PreAlerta + asociacion con paquetes | 5 |
| 2.3 | Wizard de 3 pasos cliente: reempaque? → consolidar? → tipo envio | 5 |
| 2.4 | Editor Pre-Alerta cliente: agregar trackings, contenido, badges | 5 |
| 2.5 | Vista lista Pre-Alertas cliente (cards en grid) | 5 |
| 2.6 | Vista lista Pre-Alertas admin (tabla con filtros, 12k+ registros) | 5 |
| 2.7 | Admin: Crear/Editar pre-alerta con atajos F6/F8/F9 | 5 |
| 2.8 | Vinculacion automatica: paquete etiquetado en Miami ↔ pre-alerta existente | 5, 6 |
| 2.9 | Notificaciones al cliente (email) al recibir paquete en Miami | 5 |
| 2.10 | Boton "Limpiar Vacias" | 5 |

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

### Fase 3b/3c/3d — Pendiente

| # | Tarea | Modulos |
|---|-------|---------|
| 3.8 | Notas de Debito (auto-gatillado por cambio de servicio) | 17 |
| 3.9 | Notas de Credito | — |
| 3.10 | Cotizaciones + Proformas | 13, 14 |
| 3.11 | Financiamientos | 18 |
| 3b | USD + tasa de cambio, emails de factura pendiente/pagada | — |
| 3d | Generacion de PDFs (Prawn/Grover) | — |

**Dependencia:** Fase 2 (pre-alertas y paquetes vinculados).

---

## Fase 4: Caja y Entrega

**Objetivo:** Cajeros procesan pagos diarios, despacho entrega paquetes.

| # | Tarea | Modulos |
|---|-------|---------|
| 4.1 | Mi Dia (POS diario): 4 secciones + apertura/cierre de caja | 19 |
| 4.2 | Ingresos de caja | 20 |
| 4.3 | Egresos de caja | 20 |
| 4.4 | Modelo Entrega: registro con receptor, identidad, firma | 10 |
| 4.5 | Vista Entrega Paquete con busqueda por tracking/cliente | 10 |
| 4.6 | Cambio de estado paquete a "entregado" al registrar entrega | 10 |

**Entregable:** Caja operativa en Honduras + entregas registradas.

**Dependencia:** Fase 3 (ventas y pagos deben existir).

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
Fase 0  ████████░░░░░░░░░░░░  Fundacion (auth, roles, layout, deploy)
Fase 1  ░░░░████████░░░░░░░░  Miami (etiquetar, manifiestos)
Fase 2  ░░░░░░░░████████░░░░  Pre-Alertas (cliente + admin)
Fase 3  ░░░░░░░░░░░░████████  Facturacion (pre-factura → venta → pago)
Fase 4  ░░░░░░░░░░░░░░██████  Caja + Entregas
Fase 5  ░░░░░░░░░░████░░░░░░  Tareas + Fotos (paralelo a F3)
Fase 6  ░░░░░░░░░░░░░░░░████  Reportes + Config
Fase 7  ░░░░░░░░░░░░░░░░░░██  Marketing CRM
Fase 8  ░░░░░░░░░░░░░░░░░░██  Inventario
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
