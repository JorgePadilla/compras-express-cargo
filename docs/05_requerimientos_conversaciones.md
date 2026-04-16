# Requerimientos del Sistema - Conversaciones con el Cliente

Sistema actual: `https://cec.rsahn.com/App/Home`

## Módulos Identificados

### Por Área Funcional (del sistema actual + mejoras solicitadas)

| # | Módulo | Área | Fuente | Estado |
|---|--------|------|--------|--------|
| **Autenticación y Usuarios** | | | |
| 1 | Login, Logout, Sesiones | Core | Conv. 2 (parcial) | Roles definidos, permisos pendiente |
| 2 | Usuarios del Sistema y Roles | Core | Conv. 2 (parcial) | 8 roles identificados |
| 3 | Portal Cliente (Mi Cuenta) | Core | Sistema actual | Capturado completo (11 páginas) |
| 4 | Portal Admin | Core | Sistema actual | Capturado completo (22 páginas) |
| **Logística** | | | |
| 5 | Pre-Alertas (cliente + admin) | Logística | Conv. 1 + sistema | Documentado con mejoras |
| 6 | Etiquetar (recepción Miami) | Logística | Sistema actual | Capturado (18 campos, F-keys) |
| 7 | Paquetes (CRUD + filtros avanzados) | Logística | Sistema actual | Capturado |
| 8 | Manifiestos | Logística | Sistema actual | Capturado |
| 9 | Pre-Facturas | Logística | Sistema actual | Capturado (admin + cliente) |
| 10 | Entregas / Despacho | Logística | Sistema actual | Capturado |
| **Ventas y Facturación** | | | |
| 11 | Clientes (CRUD + precios personalizados) | Ventas | Sistema actual | Capturado |
| 12 | Ventas (proforma → finalizada) | Ventas | Sistema actual | Capturado |
| 13 | Cotizaciones | Ventas | Sistema actual | Capturado |
| 14 | Proformas | Ventas | Sistema actual | Capturado |
| 15 | Facturas / Facturación | Ventas | Sistema actual | Capturado (cliente: Facturas Pendientes) |
| 16 | Recibos de pago | Ventas | Sistema actual | Capturado |
| 17 | Notas de Débito | Ventas | Sistema actual | Capturado |
| 18 | Financiamientos | Ventas | Sistema actual | Capturado |
| **Caja** | | | |
| 19 | Mi Día (POS diario) | Caja | Sistema actual | Capturado (4 secciones + apertura/cierre) |
| 20 | Ingresos y Egresos de Caja | Caja | Sistema actual | Capturado |
| **Marketing CRM** | | | |
| 21 | Campañas de Marketing | Marketing | Sistema actual | Capturado |
| 22 | Correos masivos (campañas + cola) | Marketing | Sistema actual | Capturado (max 100/clic) |
| 23 | WhatsApp / SMS | Marketing | Sistema actual | Identificado |
| 24 | URL Links (tracking marketing) | Marketing | Sistema actual | Identificado |
| **Productos e Inventario** | | | |
| 25 | Productos | Inventario | Sistema actual | Capturado |
| 26 | Ajustes de Inventario | Inventario | Sistema actual | Identificado |
| 27 | Traslados de Inventario | Inventario | Sistema actual | Identificado |
| **Configuración y Admin** | | | |
| 28 | Configuraciones (22 catálogos) | Admin | Sistema actual | Capturado completo |
| 29 | Reportes (12 tipos) | Admin | Sistema actual | Capturado completo |
| 30 | Estadísticas / Dashboard admin | Admin | Sistema actual | Capturado |
| 31 | Costos de Empresa | Admin | Sistema actual | Identificado (ruta /Mantenimientos/) |
| **Mejoras Nuevas (no existen en sistema actual)** | | | |
| 32 | Sistema de Tareas para Paquetes | Logística | Conv. 1 | Documentado |
| 33 | Sonidos/Audio feedback (operadores) | UX | Conv. 1 | Documentado |
| 34 | Notas del Cliente por ubicación | Logística | Conv. 1 | Documentado |
| 35 | Fotos de paquetes (cámaras Miami) | Logística | Conv. 1 | Documentado |
| 36 | Tracking multi-caja (caso DHL) | Logística | Conv. 1 | Documentado |
| 37 | Reducción de volumen (antes/después) | Logística | Conv. 1 | Documentado |
| 38 | Calculadora de costos mejorada | Cliente | Sistema actual | Capturado |
| 39 | Seguimiento público de paquete | Cliente | Sistema actual | Capturado |

### Conversaciones con el Cliente

| # | Tema | Estado |
|---|------|--------|
| 1 | Pre-alertas, tareas, audio, notas, fotos, volumen | Documentado completo |
| 2 | Login, Logout, Usuarios y Roles | Parcial — roles definidos, permisos por definir |
| 3 | Por definir (visita al cliente) | Pendiente |
| 4 | Por definir (visita al cliente) | Pendiente |

---

## Flujo de Pre-Alerta v4.0 — Especificación Canónica

> **Fuente:** [`docs/approved/pre_alerta_v4.docx`](approved/pre_alerta_v4.docx) · Abril 2026
> **Estado:** Documento aprobado (fuente oficial archivada en el repo).
> Esta sección es la **fuente de verdad** para tipos de envío, precios y reglas de pre-alerta.
> Las secciones más abajo que describen el sistema legacy (`cec.rsahn.com`) permanecen como contexto histórico — ante cualquier conflicto, **prevalece v4**.

### Servicios disponibles (v4)

**Con reempaque unitario + opción a consolidar**

| Código | Nombre | Modalidad | Precio/lb | SLA | Consolidable |
|:------:|:------|:----------|:---------:|:---:|:------------:|
| **EXPRESS** | Aéreo Express | Aéreo (sale viernes) | $8.00 | 3–7 días hábiles | Sí |
| **CER**     | Aéreo estándar | Aéreo | $4.50 | 6–10 días hábiles | Sí |
| **CEM**     | Marítimo | Marítimo | $2.50 | 14–17 días hábiles | Sí |

**Sin reempaque — sin opción a consolidar**

| Código | Nombre | Modalidad | Precio/lb | SLA | Regla |
|:------:|:------|:----------|:---------:|:---:|:------|
| **CKA** | Aéreo | Aéreo | $4.00 | 6–10 días hábiles | Máximo 1 paquete por acción |
| **CKM** | Marítimo | Marítimo | $1.50 | 14–17 días hábiles | Máximo 1 paquete por acción |

### Reglas del flujo (v4)

- **Límite por acción (CKA/CKM):** solo permiten **1 paquete por acción** para evitar malos entendidos.
- **Límite por consolidación:** solo las pre-alertas **consolidadas** pueden tener múltiples paquetes. Las pre-alertas sin consolidar (EXPRESS/CER/CEM con `consolidado=false`, CKA, CKM) se limitan a **1 paquete**. El botón "Agregar Paquete" se oculta tanto en el wizard como en la edición cuando no es consolidado.
- **Consolidación:** disponible en **EXPRESS, CER y CEM**. Permite elegir entre consolidar o solo reempacar sin consolidar. **Sin costo adicional.** Debe solicitarse **antes de que el paquete llegue a Honduras**.
- **Tracking:** opcional en todos los servicios — puede omitirse al crear la pre-alerta y agregarse después.
- **Notas del cliente:** se muestran automáticamente al crear la pre-alerta. (⚠️ bug activo en Miami del sistema legacy, pendiente de corrección en la implementación nueva.)
- **Default:** paquetes sin tipo de envío asignado se procesan automáticamente como **CER**.

### Implicaciones para la implementación

> **Estado:** ✅ Implementado (Abril 2026). Código, seeds y wizard de pre-alerta del portal cliente alineados con v4.

- [x] El seed de `TipoEnvio` refleja los 5 servicios canónicos (`EXPRESS`, `CER`, `CEM`, `CKA`, `CKM`) con sus precios, SLA y flags `con_reempaque` / `consolidable` / `max_paquetes_por_accion`.
- [x] El wizard de Pre-Alerta permite consolidar en **EXPRESS** (el sistema legacy lo marcaba como "SIN CONSOLIDAR", obsoleto con v4).
- [x] Validación: al crear una pre-alerta CKA o CKM, se rechaza si el payload contiene más de 1 paquete (`PreAlerta#respect_max_paquetes_por_accion`).
- [x] Precio de CKM pasa de **$1.90/lb** (legacy) a **$1.50/lb** (v4).
- [x] Tracking es opcional en `PreAlertaPaquete` (solo valida unicidad cuando está presente).
- [x] Al crear una pre-alerta sin `tipo_envio_id`, se asigna CER automáticamente (`PreAlerta#assign_default_tipo_envio`).
- [x] UI del wizard refleja el flujo del diagrama v4: **Servicio → Consolidación → Datos del paquete** (se eliminó el orden invertido previo de reempaque/consolidar/servicio).
- [x] `pre_alerta_paquetes` tiene `valor_declarado` y `peso` (opcionales, `decimal(10,2)`) capturables en el wizard y en la edición.
- [x] Aviso inline en rojo "1 paquete por acción" al seleccionar CKA/CKM en el paso 1 del wizard.

---

## Conversación 1: Pre-alertas y Mejoras al Sistema Actual

### 1. Sistema de Tareas para Paquetes

**Problema:** No existe un sistema de tareas para operaciones especiales sobre paquetes.

**Ejemplo del cliente:**
- Juana deja un paquete personal de Jorge
- Jorge quiere: el celular por Express, la ropa por marítimo
- Esto debe quedar como **tareas asignadas** al operador
- La tarea NO se puede cerrar/liberar hasta que el operador marque como **hecho/realizado**
- Necesita control tipo checklist con verificación

**Requerimientos:**
- [ ] Crear modelo de Tareas asociadas a paquetes
- [ ] Tareas pueden incluir: separar items, re-empacar, enviar por diferentes modalidades (express/marítimo)
- [ ] Estado de tareas: pendiente → en proceso → realizado
- [ ] El paquete no avanza en el flujo hasta que todas sus tareas estén completadas
- [ ] Interfaz de checklist para operadores

### 2. Re-empaque (Re-empaque como Servicio)

**Contexto:** El re-empaque involucra personas y espacio. Es un proceso operativo.

**Beneficio:** Los paquetes vienen consolidados y se paga menos en transporte.

**Requerimientos:**
- [ ] Servicio de re-empaque disponible en el sistema
- [ ] Asociar re-empaque como tarea del paquete
- [ ] Tracking de quién realizó el re-empaque

### 3. Sonidos/Notificaciones al Digitar

**Problema:** No hay feedback auditivo al ingresar tracking numbers.

**Requerimientos:**
- [ ] Sonido de confirmación al ingresar un tracking en pre-alerta
- [ ] Sonido diferente para errores o duplicados
- [ ] Feedback auditivo durante el proceso de digitación

### 4. Notas del Cliente en Pre-alertas

**Problema:** Las notas del cliente aparecen en Honduras pero NO aparecen en Miami al hacer pre-alertas.

**Ejemplo del cliente:**
- Nota Miami: "Siempre tratar de embolsarle todos los productos"
- Nota Honduras: "Enviarle foto al estar disponible"
- Cuando el operador en Miami escanea/digita una pre-alerta, las notas de Miami NO se muestran

**Requerimientos:**
- [ ] Mostrar notas del cliente automáticamente al iniciar una pre-alerta
- [ ] Notas segmentadas por ubicación (Miami / Honduras)
- [ ] Las notas deben ser visibles y destacadas (no pasar desapercibidas)
- [ ] Popup o banner con las notas al escanear el primer tracking del cliente

### 5. Tracking: Ciclo de Vida y Duplicados

**Contexto:** Los carriers (DHL, etc.) reciclan tracking numbers después de ~2 años.

**Sistema actual (Roger lo construyó):**
- Detecta cuando un tracking ya fue recibido y asignado
- Una vez que el tracking llega a estado "disponible" (entregado), se libera de la base de datos pendiente
- Permite reutilización futura del mismo tracking number

**Problema con DHL:** Usan el **mismo tracking para múltiples cajas** (1 tracking = 5 cajas). Esto genera complejidad.

**Requerimientos:**
- [ ] Mantener lógica de ciclo de vida de tracking (~2 años)
- [ ] Liberar tracking de pendientes cuando llega a estado "disponible/entregado"
- [ ] Soportar 1 tracking → múltiples cajas (caso DHL)
- [ ] Alerta de tracking duplicado/reciclado con contexto (mostrar historial)

### 6. Fotos de Paquetes en Recepción (Miami)

**Contexto:** Al abrir cajas en Miami, necesitan documentar el contenido con fotos. Actualmente hay 2 cámaras por estación de trabajo.

**Setup físico por estación (~$1,000+ USD):**
- Mesa de trabajo ($250)
- 2 cámaras ($100-150 c/u)
- Computadora ($500)
- Monitor ($100)
- Switch USB + estante

**Requerimientos:**
- [ ] Botón/clic en el sistema para capturar fotos desde las cámaras de la estación
- [ ] Adjuntar fotos automáticamente al registro del paquete
- [ ] Adjuntar fotos al correo de notificación al cliente
- [ ] Considerar IA para detectar contenido al abrir la caja (mencionado como ideal futuro)
- [ ] Soporte para 2 cámaras por estación (vista general + detalle)

### 7. Re-empaque y Reducción de Volumen

**Contexto:** Los operadores en Miami reducen el tamaño de las cajas manualmente (cortan cartón) para bajar el volumen cobrado al cliente. Esto es un diferenciador vs. la competencia.

**Ejemplo:** Caja de 18x15x14 → recortada a 18x15x6 = ahorro significativo en volumen.

**Fórmula volumen:** `largo x ancho x alto / 166 = libras volumétricas`

**Requerimientos:**
- [ ] Registrar dimensiones originales y finales del paquete
- [ ] Calcular ahorro en volumen automáticamente
- [ ] Mostrar al cliente el beneficio del re-empaque (antes/después)

### 8. Patrón de UI Consistente + Búsquedas y Filtros

**Del cliente:** "La plantilla es la misma casi. Búsqueda, filtro por fecha. Lo que cambia son unas cositas."

**Requerimientos:**
- [ ] Plantilla base reutilizable para todos los módulos: búsqueda + filtros + tabla de resultados
- [ ] Cada módulo solo cambia columnas y acciones específicas
- [ ] Roger está agregando nuevos "cuadros" al sistema actual que servirán de referencia

**Búsquedas y filtros inteligentes (para páginas con muchos registros):**
- [ ] Búsqueda por texto libre (tracking, nombre, código cliente, No. documento)
- [ ] Filtro por rango de fechas (desde/hasta)
- [ ] Filtro por estado (PRE-ALERTA, FACTURADO, ADUANA, DISPONIBLE, etc.)
- [ ] Filtro por tipo de envío (CER, CKA, CEM, CKM, EXP)
- [ ] Filtro por ubicación (Miami / Honduras)
- [ ] Filtro por operador / creado por
- [ ] Toggle: mostrar anulados / agrupados / antiguos
- [ ] Paginación con tamaño de página configurable
- [ ] Ordenamiento por columna (asc/desc)
- [ ] Los filtros deben ser combinables (ej: fecha + estado + tipo envío)

### 9. Mejoras Generales Identificadas

- [ ] Compatibilidad cross-browser (Chrome, Edge, otros) — el cliente reportó problemas con popups bloqueados
- [ ] Las notas del cliente deben funcionar en todos los navegadores

---

## Sistema Actual (cec.rsahn.com) — Análisis Detallado

```
Pre-alerta → Recepción Miami → Pre-factura → Factura → Pago → Entrega
```

### Navegación Admin (Logística)
**URL:** `/Logistica/Paquetes/PreAlertas`

**Sidebar:**
- Home
- Estadísticas (Dashboard)
- Mi Día (Transacciones)
- **Logistica:** Paquetes, Pre-Alertas, Manifiestos, Pre-Facturas, Entregas
- **Marketing CRM:** Campañas, Correos, URL Links, WhatsApp, SMS
- **Ventas:** Clientes, Todas las Ventas, Financiamientos, Proformas, Cotizaciones, Recibos, Notas de Débito
- **Productos:** Todos los Productos, Ajustes Inventario, Traslados de Inv.
- **Administracion:** Costos de Empresa, Ingresos de Caja, Egresos de Caja
- Configuraciones
- Reportes

**Vista lista Pre-Alertas (admin):**
- Botón "Crear Pre-Alerta"
- Búsqueda: Tracking/No. Recepcion/No. Pre-Alerta/No. Pre-Factura
- Botón "Limpiar Vacías"
- Filtros toggle: Mostrar solo anulados / Mostrar solo agrupados / Incluir antiguos a 6 meses
- Tabla con columnas: Fecha | No. Documento | Nombre Cliente | Codigo C. | T.E. | AGR | FIN | Creado Por | Notif. | C.E. | Cant. | (acciones: editar, más, eliminar)
- Paginación: 1242 páginas, 12,413 elementos
- Tamaño de página configurable

### Navegación Cliente (Mi Cuenta)
**URL:** `/MiCuenta/Paquetes/PreAlertas`

**Sidebar:**
- Inicio
- Paquetes
- Pre-Alertas
- Pre-Facturas
- Facturas Pendientes
- Calculadora
- Mis Direcciones
- Sugerencias
- Contáctenos
- Privacidad / Términos / Cambiar Contraseña / Salir

**Vista lista Pre-Alertas (cliente):**
- Botón "Agregar Pre-Alerta"
- Búsqueda simple (Buscar...)
- Botón "Limpiar"
- Cards en grid (no tabla) con: No. Documento, Badges (PRE-ALERTA / PRE-ALERTA CON REEMPAQUE / CONSOLIDADO), Fecha, Cliente, T.E. (tipo envío), Cant.
- Acciones por card: Editar → / Eliminar ×

### Formulario Crear Pre-Alerta (Cliente) — Wizard de 3 pasos

**Paso 1:** ¿Desea reempacar los paquetes?
- Radio: Reempacar / Sin reempaque
- Nota explicativa: "Reempacar significa que en Miami abrimos tu caja original (ejemplo: Amazon) y pasamos el contenido a una bolsa más pequeña para reducir espacio y costo."

**Paso 2:** ¿Desea consolidar varios paquetes?
- Radio: Sí, consolidar varios paquetes en uno solo / No, manejar los paquetes de forma independiente

**Paso 3:** Seleccione el tipo de envío (opciones dinámicas según pasos anteriores)
- CON REEMPAQUE + CONSOLIDAR:
  - EXPRESS - AEREO EXPRESS CON REEMPAQUE CONSOLIDADO (v4: EXPRESS es consolidable)
  - CER - AEREO CON REEMPAQUE CONSOLIDADO
  - CEM - MARITIMO CON REEMPAQUE CONSOLIDADO
- CON REEMPAQUE + SIN CONSOLIDAR:
  - EXPRESS - AEREO EXPRESS CON REEMPAQUE SIN CONSOLIDAR
  - CER - AEREO CON REEMPAQUE SIN CONSOLIDAR
  - CEM - MARITIMO CON REEMPAQUE SIN CONSOLIDAR
- SIN REEMPAQUE:
  - CKA - AEREO (máximo 1 paquete por acción)
  - CKM - MARITIMO (máximo 1 paquete por acción)

> **v4:** El sistema legacy marcaba `EXP - AEREO EXPRESS SIN CONSOLIDAR` como única opción. En v4, EXPRESS admite consolidación (sin costo adicional). Ver sección canónica v4 al inicio del documento.

**Botón:** Agregar detalles del paquete (F6)

### Editor Pre-Alerta (Cliente)

**Campos:**
- No. Documento: PA00XXXXXX (auto-generado)
- Título dinámico: ej. "CER-AEREO CON REEMPAQUE" o "CEM-MARITIMO CON REEMPAQUE"
- Notas del grupo (opcional): textarea "Ingrese las observaciones"
- Botón: "Buscar Paquete"

**Sección PAQUETES (repetible):**
- Tracking: textbox "Ingrese el tracking"
- Descripción: textbox "Ingrese la descripción"
- Fecha: auto (fecha actual)
- Checkbox: "Retener paquete en Miami"
- Estado: PRE-ALERTA / FACTURADO / etc.
- Botón rojo: "Borrar de la pre-alerta"
- Botón verde: "Mover a otra pre-alerta"

**Botón:** "Agregar otro paquete" (añadir más trackings)

**Acciones de guardado:**
- "Guardar y Notificar (F9)" — guarda y envía notificación
- "Solo Guardar (F8)" — guarda sin notificar

**Modales disponibles:**
- Pre-Factura
- Seleccionar Grupo
- Seleccionar Paquete
- Logs

### Tipos de Envío (T.E.) Identificados

> ⚠️ **Obsoleto en la parte del código legacy "EXP".** Ver [Flujo de Pre-Alerta v4.0](#flujo-de-pre-alerta-v40--especificación-canónica) — el código canónico es `EXPRESS`, no `EXP`.

| Código | Significado |
|--------|------------|
| CER | Carga Express Aéreo (con reempaque) |
| CEM | Carga Express Marítimo (con reempaque) |
| CKA | Carga Kilo Aéreo (sin reempaque) |
| CKM | Carga Kilo Marítimo (sin reempaque) |
| EXP *(legacy)* | Express (aéreo rápido) — renombrado a **EXPRESS** en v4 |

### Estados de Paquete Identificados
- PRE-ALERTA
- FACTURADO
- ADUANA
- DISPONIBLE (en Honduras)

### Versión del sistema actual
- Sistemas RSA vBETA-4.73
- Copyright 2022-2026

---

### Portal Cliente — Todas las Páginas

#### 1. Dashboard / Inicio (`/MiCuenta/Dashboard`)
- Nombre completo del cliente
- Código del Cliente (ej: C5344)
- Saldo Actual (en Lempiras, ej: L0.00)
- Notificaciones WhatsApp (número registrado)
- Quick links en grid: Mis Paquetes, Agregar Pre-Alerta, Pre-Alertas, Pre-Facturas, Facturas Pendientes, Calculadora de costos, Mis Direcciones, Enviar Sugerencia, Contáctenos, Cambiar Contraseña, Cerrar Sesión

#### 2. Paquetes (`/MiCuenta/Paquetes/`)
- Búsqueda: "Filtrar por tracking, contenido, estado..."
- Botón "Limpiar"
- Contador: "Mostrando X de Y"
- Cards con: Tracking (ej: TBA328330914785-2), Badge estado (PRE-ALERTA), Fecha, Cant., Contenido (descripción del producto), Tipo Envío
- Acciones: "Ver detalles →", "Asignar Pre-Alerta"

#### 3. Pre-Alertas (`/MiCuenta/Paquetes/PreAlertas`)
- (Ya documentado arriba en detalle)

#### 4. Pre-Facturas (`/MiCuenta/Paquetes/PreFacturas`)
- Búsqueda: "Introduzca el texto a buscar..."
- Tabla (columnas no visibles por falta de datos)
- Muestra "Sin datos para mostrar" cuando vacío

#### 5. Facturas Pendientes (`/MiCuenta/Facturacion/`)
- Búsqueda: "Introduzca el texto a buscar..."
- Tabla con columnas: Fecha | No. Documento | nombre | Referencia | Total | Saldo
- Muestra "Sin datos para mostrar" cuando vacío

#### 6. Calculadora de Costos (`/MiCuenta/Paquetes/Calculadora/`)

> *Captura del sistema legacy. Para la implementación nueva, usar los códigos canónicos v4 (ver sección al inicio del documento): el dropdown debe listar `EXPRESS` en lugar de `EXP`.*

- **Tipo de Envío** (dropdown):
  - Sin Definir (default, en v4 se asigna **CER** automáticamente)
  - CKA - AEREO SIN REEMPAQUE (value=1)
  - CER - AEREO CON REEMPAQUE (value=2)
  - CKM - MARITIMO SIN REEMPAQUE (value=3)
  - CEM - MARITIMO CON REEMPAQUE (value=4)
  - EXP - AEREO EXPRESS (value=5) *(legacy · v4: `EXPRESS`)*
- **Peso (libras):** input numérico
- **Alto (pulgadas):** input numérico
- **Largo (pulgadas):** input numérico
- **Ancho (pulgadas):** input numérico
- **Botón:** "Calcular Precio"
- **Dimensión:** campo calculado (auto)
- **Total (ya incluye el impuesto):** campo calculado (auto)

#### 7. Mis Direcciones (`/MiCuenta/Paquetes/MisDirecciones`)
Muestra direcciones de envío en Miami por tipo, cada una con pricing:

**CER - AÉREO CON REEMPAQUE Y OPCIÓN A CONSOLIDAR:**
- $4.50 por libra o tamaño + ISV
- 6 a 10 días hábiles
- Cobro mínimo SPS: L200.00, Tegucigalpa: L200.00 (ISV incluido)
- Dirección: 8109 NW 60th ST, Miami, FL 33195-3415
- Tel: 305-848-0990
- LÍNEA 2: REEMPAQUE AEREO

**CKA - AÉREO SIN REEMPAQUE NI CONSOLIDADO:**
- $4.00 por libra o tamaño + ISV
- 6 a 10 días hábiles
- Máximo 1 paquete por acción (v4)
- Cobro mínimo SPS: L200.00, Tegucigalpa: L200.00 (ISV incluido)
- LÍNEA 2: AEREO CKA

**EXPRESS - AÉREO EXPRESS:** *(legacy: `EXP`)*
- $8.00 por libra o tamaño + ISV
- 3 a 7 días hábiles
- Cobro mínimo SPS y Tegucigalpa: $14.95 ISV incluido
- Vuela una vez a la semana los viernes a las 10:00 AM
- v4: admite consolidación sin costo adicional
- LÍNEA 2: EXPRESS

**CEM - MARÍTIMO CON REEMPAQUE Y OPCIÓN A CONSOLIDAR:**
- $2.50 por libra o tamaño + ISV
- 14 a 17 días hábiles
- Mínimo 8 libras
- LÍNEA 2: REEMPAQUE MARITIMO

**CKM - MARÍTIMO SIN REEMPAQUE NI CONSOLIDADO:**
- ~~SPS: $1.90 por libra~~ · **v4: $1.50 por libra** o tamaño + ISV
- 14 a 17 días hábiles
- Máximo 1 paquete por acción (v4)
- Mínimo 20 libras
- LÍNEA 2: MARITIMO CKM

**Formato dirección (todas usan):**
- NOMBRE: [CÓDIGO] [CÓDIGO_CLIENTE] [NOMBRE_COMPLETO]
- LÍNEA 1: 8109 NW 60th ST
- LÍNEA 2: [Varía según tipo envío]
- CIUDAD: MIAMI
- ESTADO: FLORIDA
- CÓDIGO POSTAL: 33195-3415
- TELÉFONO: 305-848-0990
- PAÍS: USA

#### 8. Sugerencias (`/MiCuenta/Dashboard/Sugerencias`)
- Botón "Agregar Sugerencia"
- Búsqueda: "Introduzca el texto a buscar..."
- Lista de sugerencias enviadas (tabla)

#### 9. Contáctenos (`/MiCuenta/Dashboard/Direcciones`)
- Empresa: CORPORACION KARSAM S DE RL DE C.V.
- Oficina: San Pedro Sula
- Horario: L-V 8:30am-5:30pm, Sábado 8:30am-4:00pm
- Email: sac@comprasexpresshn.com
- PBX: +(504) 2516-2853
- WhatsApp: +504 9440-4477, +504 9440-1136
- Dirección: Entre 7 y 8 calle 22 ave N.O. Col Zeron, frente a la Vaquita Mercato y Brinkos, San Pedro Sula, Honduras
- Mapa Google Maps embebido

#### 10. Seguimiento del Paquete (`/MiCuenta/Paquetes/Seguimiento/`)
- Página pública (no requiere login)
- Campo: "Tracking" (input)
- Mensaje: "Ingrese el tracking del paquete"
- Muestra info de contacto de la empresa debajo

#### 11. Atajos de Teclado (F-Keys)

**Confirmados en el sistema actual (Pre-Alerta editor):**

| Atajo | Acción | Función JS |
|-------|--------|-----------|
| F6 | Agregar detalles del paquete (crear nuevo grupo) | `AgregarGrupoPreAlerta()` |
| F8 | Solo Guardar (sin notificar) | `GuardarPreAlerta(false)` |
| F9 | Guardar y Notificar al cliente | `GuardarPreAlerta(true)` |

**Nota:** En la vista cliente, los F-keys están como labels en los botones pero no tienen global keydown handlers. El binding de teclado probablemente existe en la vista admin/logística (operadores Miami).

**Funciones JS encontradas en el editor:**
- `CrearNuevaPreAlerta()`
- `LimpiarPreAlerta()`
- `SetPrealertaInfo()`
- `GuardarPreAlerta(notificar)`
- `AgregarGrupoPreAlerta()`

#### 12. Audio / Sonidos

**Estado actual:** NO hay implementación de audio en la vista cliente. No se encontraron elementos `<audio>`, archivos `.mp3/.wav`, ni funciones de sonido.

**Lo que pidió el cliente (de conversación 1):**
- Sonido de confirmación al ingresar un tracking en pre-alerta (lado operador/Miami)
- Sonido diferente para errores o duplicados
- Feedback auditivo durante digitación de trackings
- Esto es para el **lado admin/logística**, no el portal del cliente

**Requerimiento para el nuevo sistema:**
- [ ] Sonido de éxito al escanear/digitar tracking válido
- [ ] Sonido de error al tracking duplicado o inválido
- [ ] Sonido de alerta cuando aparecen notas del cliente
- [ ] Implementar con Web Audio API o `new Audio()` en la vista de operadores

#### 13. Otras páginas del sidebar
- **Privacidad** (`/MiCuenta/Dashboard/Privacidad`)
- **Términos** (`/MiCuenta/Dashboard/Terminos`)
- **Cambiar Contraseña** (`/MiCuenta/Manage/ChangePassword`)

---

### Portal Admin — Todas las Páginas

#### Navegación Completa (Sidebar Admin)

```
Home                          → /App/Home
Estadísticas                  → /App/Dashboard
Mi Día                        → /App/Transacciones
Logistica/
  ├── Paquetes                → /Logistica/Paquetes/
  ├── Pre-Alertas             → /Logistica/Paquetes/PreAlertas
  ├── Manifiestos             → /Logistica/Manifiestos
  ├── Pre-Facturas            → /Logistica/Paquetes/PreFacturas
  └── Entregas                → /App/Entregas
Marketing CRM/
  ├── Campañas                → /Marketing/CampañaVentas
  ├── Correos                 → /Marketing/Correos
  ├── URL Links               → /Marketing/DireccionURL
  ├── WhatsApp                → /Marketing/WhatsApp
  └── SMS                     → /Marketing/SMS
Ventas/
  ├── Clientes                → /App/Clientes
  ├── Todas las Ventas        → /App/Ventas
  ├── Financiamientos         → /App/Financiamientos
  ├── Proformas               → /App/Proformas
  ├── Cotizaciones            → /App/Cotizaciones
  ├── Recibos                 → /App/Recibos
  └── Notas de Débito         → /App/NotasDebito
Productos/
  ├── Todos los Productos     → /App/Productos
  ├── Ajustes Inventario      → /App/Ajustes
  └── Traslados de Inv.       → /App/Traslados
Administracion/
  ├── Costos de Empresa       → /Mantenimientos/ConfigurarCostos
  ├── Ingresos de Caja        → /Mantenimientos/Ingresos
  └── Egresos de Caja         → /Mantenimientos/Egresos
Configuraciones               → /App/Configuraciones
Reportes                      → /App/Reportes
```

**Global:** Todas las páginas admin tienen toggle "Oscuro" (dark mode) y botón "Activar" (notificaciones push). Footer: "Copyright 2022-2026 Sistemas RSA. vBETA-4.73" + botón "Enviar Sugerencia".

#### A1. Home (`/App/Home`)
Dashboard administrativo organizado por áreas de trabajo:

| Área | Accesos Rápidos |
|------|----------------|
| **Miami** | Etiquetar, Manifiesto, Clientes, Todos los Paquetes |
| **Caja** | Pre-Facturas, Todos los Paquetes, Pre-Alertas, Todas las Ventas, Recibos |
| **Facturación** | Pre-Facturas, Pre-Alertas, Todos los Paquetes, Clientes |
| **Entrega** | Entrega Paquete |
| **Marketing CRM** | Correos, WhatsApp, SMS |

#### A2. Estadísticas (`/App/Dashboard`)
- Botón: "Mostrar Gráficos"
- Carga 3 tipos de datos: gráfico de ventas, financiamientos, estadísticas generales
- Nota: página con errores frecuentes al cargar en sistema actual

#### A3. Mi Día (`/App/Transacciones`)
Vista diaria del cajero/operador:
- **Acciones:** Nueva Venta, Agregar Ingreso, Agregar Egreso
- **Botón derecha:** Apertura/Cierre (apertura y cierre de caja)
- **4 secciones (lazy load con "Cargar Lista"):**
  1. Ventas Proforma
  2. Ventas Finalizadas
  3. Ingresos
  4. Egreso

#### A4. Logistica > Etiquetar (`/Logistica/Paquetes/Etiquetar`)
Formulario de etiquetado/digitación de paquetes en Miami.
**Rol principal:** Digitador Miami | **Supervisa:** Supervisor de Miami

| Campo | Tipo | Descripción |
|-------|------|-------------|
| No. Tracking | text | Tracking del paquete |
| Expedido por | dropdown | Carrier (Amazon, DHL, etc.) |
| Código del Cliente | text + autocomplete | Código ej: C5344 |
| Proveedor del Paquete | text | Tienda origen |
| Nombre del Cliente | text (auto) | Se llena al ingresar código |
| Notas del Cliente | textarea (read-only) | Notas guardadas del cliente |
| Tipo de Envío | dropdown | CER, CKA, CEM, CKM, EXP |
| RETENER EL PAQUETE | checkbox | Retener en Miami |
| Contenido del Paquete | textarea | Descripción contenido |
| Notas Internas | textarea | Notas para operadores |
| Cantidad Productos | number | Cantidad items dentro |
| Cantidad Paquetes | number | Cantidad de bultos |
| Peso Real | number | Peso en libras |
| Alto | number | Pulgadas |
| Largo | number | Pulgadas |
| Ancho | number | Pulgadas |
| Peso Volumétrico | calculated | largo × ancho × alto / 166 |
| Peso a Cobrar | calculated | max(peso real, peso volumétrico) |

**Atajos de teclado:**
- F2: Limpiar formulario
- F8: Guardar
- F9: Guardar e Imprimir etiqueta

#### A5. Logistica > Pre-Alertas Admin (`/Logistica/Paquetes/PreAlertas`)
- **Acciones:** Crear Pre-Alerta, Limpiar Vacías
- **Búsqueda:** Tracking/No. Recepcion/No. Pre-Alerta/No. Pre-Factura
- **Filtros toggle:** Mostrar solo anulados / Mostrar solo agrupados / Incluir antiguos a 6 meses
- **Búsqueda en tabla:** texto libre
- **Tabla:** Fecha, No. PA, Nombre Cliente, Código, Tipo Envío, checkboxes status (DevExpress), Origen (SITIO WEB), checkboxes notificación, Cant. paquetes, acciones (editar, detalles, eliminar)
- **Volumen:** 12,413+ registros, paginado

#### A6. Logistica > Manifiestos (`/Logistica/Manifiestos`)
- **Tabla columnas:** Fecha, No. Manifiesto, Trackings, Carrier (PRONTO CARGO, SERCARGO, GENESIS), Estado (ENVIADO, ADUANA), Tipo *(legacy muestra `AEREO, AEREO EXPRESS, CKM MARITIMO, CKA ESTANDARD` — v4: `EXPRESS, CER, CEM, CKA, CKM`)*, Cantidades, Pesos, Montos

#### A7. Logistica > Paquetes (`/Logistica/Paquetes/`)
Vista con filtros avanzados:
- **Filtros dropdown:** Tipo de Envío, Estado
- **Filtros fecha:** Fecha Inicio, Fecha Fin
- **Filtros texto:** Código Cliente, Nombre Cliente (dropdown)
- **Filtros toggle:** Mostrar solo facturados, Mostrar solo anulados, Mostrar solo sin Pre-Alerta, Mostrar solo sin Pre-Factura, Incluir antiguos a 6 meses
- **Leyenda colores:** P.A.=Pre-Alerta, P.F.=Pre-Factura, Amarillo=Solicito Cambio de Servicio, Azul=Retener en Miami

#### A8. Logistica > Pre-Facturas Admin (`/Logistica/Paquetes/PreFacturas`)
- **Filtros:** Tipo de Envío (dropdown), Fecha Inicio/Fin, Código Cliente, Nombre Cliente
- **Toggles:** Mostrar facturadas, Mostrar anulados, Filtro por fecha de trabajo, Incluir antiguos a 6 meses
- **Tabla:** Fecha, No. PF, Nombre Cliente, Código, Tipo, Iniciales operador, Notas, checkmarks, Monto (Lempiras)

#### A9. Logistica > Entregas (`/App/Entregas`)
- **Acción:** Nueva Entrega
- **Búsqueda:** texto libre
- **Tabla:** Fecha, No. Entrega (EN000XXXXX), Nombre Cliente, Código Cliente, Pre-Factura# + Tipo (ej: PF00352881 - CER), Nombre Operador, acciones (detalles, eliminar)

#### A10. Ventas > Clientes (`/App/Clientes`)
- **Acciones:** Nuevo Cliente, Asignar precios a clientes (precios personalizados por cliente)
- **Toggle:** Mostrar solo clientes con saldo pendiente
- **Leyenda:** C.E.= Correo Enviado, C.C.= Correo Confirmado
- **Nota:** Carga lenta con muchos clientes

#### A11. Ventas > Todas las Ventas (`/App/Ventas`)
- **Acciones:** Nueva Venta, Limpiar Vacías
- **Toggles:** Mostrar solo ventas con saldo pendiente, Incluir antiguos a 6 meses

#### A12. Ventas > Financiamientos (`/App/Financiamientos`)
- Lista simple de financiamientos de clientes

#### A13. Ventas > Proformas (`/App/Proformas`)
- **Acciones:** Nueva Venta, Limpiar Vacías
- **Toggle:** Incluir antiguos a 6 meses

#### A14. Ventas > Cotizaciones (`/App/Cotizaciones`)
- **Acción:** Nueva Cotización

#### A15. Ventas > Recibos (`/App/Recibos`)
- **Toggle:** Incluir antiguos a 6 meses

#### A16. Ventas > Notas de Débito (`/App/NotasDebito`)
- **Acciones:** Nueva Nota de Débito, Limpiar Vacías
- **Toggles:** Mostrar solo notas de débito con saldo pendiente, Incluir antiguos a 6 meses

#### A17. Marketing CRM > Campañas (`/Marketing/CampañaVentas`)
- **Acción:** Nueva Campaña
- **Toggle:** Mostrar campañas de todos los vendedores

#### A18. Marketing CRM > Correos (`/Marketing/Correos`)
- **Acción:** Crear Correo
- **Sección 1: Campañas de Correo** — Lista con búsqueda, paginación (tamaño de página: 20), columnas: Fecha, Nombre Campaña, Conteo, acciones
- **Sección 2: Cola de Correos** — Botón "Enviar correos", nota: "Se enviarán máximo 100 correos por cada clic", lista de correos pendientes

#### A19. Productos > Todos los Productos (`/App/Productos`)
- **Acciones:** Crear Nuevo Producto, Recargar Lista

#### A20. Configuraciones (`/App/Configuraciones`)
Listado de 22 configuraciones del sistema, cada una con botón "Editar":

| # | Configuración | Propósito |
|---|--------------|-----------|
| 1 | Mi Cuenta | Datos del usuario actual |
| 2 | Cambio del Día (tasa de cambio) | Tasa USD→HNL diaria |
| 3 | Carriers de Carga o Expedido Por | Transportistas (Amazon, DHL, FedEx, etc.) |
| 4 | Categorías de Precios | Planes de precio por tipo cliente |
| 5 | Cola de correos (Logistica) | Config cola de emails logística |
| 6 | Consignatarios (manifiestos) | Destinatarios de manifiestos |
| 7 | Correos de la Empresa | Emails corporativos |
| 8 | Egreso de Caja | Tipos de egresos de caja |
| 9 | Empleados | Gestión de empleados |
| 10 | Empresas de Manifiestos (Logistica) | Empresas de transporte para manifiestos |
| 11 | Ingresos de Caja | Tipos de ingresos de caja |
| 12 | Lugares (Logistica) | Ubicaciones (Miami, SPS, Tegucigalpa) |
| 13 | Motivos Notas de Crédito | Razones para notas de crédito |
| 14 | Puntos de Emisión | Puntos de facturación |
| 15 | Reportes Plantillas | Templates de reportes |
| 16 | Tamaños de Cajas (Logistica) | Catálogo de tamaños de cajas |
| 17 | Teléfonos WhatsApp | Números de WhatsApp del negocio |
| 18 | Tipos de Egreso | Categorías de gastos |
| 19 | Tipos de envío (manifiestos) | Tipos para manifiestos |
| 20 | Tipos de Envíos (Logistica) | CER, CKA, CEM, CKM, EXP |
| 21 | Tipos de Ingresos | Categorías de ingresos |
| 22 | Usuarios del Sistema | Gestión de usuarios y permisos |

#### A21. Reportes (`/App/Reportes`)
12 reportes disponibles, cada uno con botón "Ver":

| Reporte | Descripción probable |
|---------|---------------------|
| Antigüedad de Saldos | Aging de cuentas por cobrar |
| Cierres de Caja | Historial de aperturas/cierres de caja |
| Clientes | Reporte de clientes |
| Estados de Cuenta | Estados de cuenta por cliente |
| Historial de correos enviados | Log de emails enviados |
| Notas de Débito | Reporte de notas de débito |
| Notificaciones | Historial de notificaciones |
| Paquetes | Reporte de paquetes |
| PreFacturas | Reporte de pre-facturas |
| Reporte Diario | Resumen del día |
| Sugerencias | Sugerencias de clientes |
| Ventas | Reporte de ventas |

#### A22. Administración (rutas `/Mantenimientos/`)
- **Costos de Empresa** (`/Mantenimientos/ConfigurarCostos`) — Configuración de costos operativos
- **Ingresos de Caja** (`/Mantenimientos/Ingresos`) — Gestión de ingresos
- **Egresos de Caja** (`/Mantenimientos/Egresos`) — Gestión de egresos

**Nota:** Estas rutas usan path `/Mantenimientos/` (diferente a `/App/`), pueden requerir permisos adicionales.

### Patrones UI Comunes (Admin)

**Patrón lista estándar:**
1. Título de página
2. Botón acción principal (Nueva Venta / Crear / etc.) — azul oscuro
3. Botón secundario opcional (Limpiar Vacías) — rojo, alineado derecha
4. Filtros/toggles en barra gris
5. Barra de búsqueda de texto libre
6. Tabla de datos (DevExpress grid)
7. Paginación inferior con selector de tamaño de página
8. Acciones por fila: ver detalles (icono clipboard), eliminar (icono trash)

**Filtros recurrentes:**
- "Incluir antiguos a 6 meses" — presente en casi todas las listas
- "Mostrar solo con saldo pendiente" — en Ventas, Notas Débito, Clientes
- "Mostrar solo anulados" — en Pre-Alertas, Paquetes
- "Limpiar Vacías" — elimina registros sin contenido (Pre-Alertas, Ventas, Proformas, Notas Débito)

**Tecnología actual:** ASP.NET MVC + DevExpress Controls (dxWeb_edtCheckBox_Moderno), jQuery, sin SPA (full page loads).

---

## Conversación 2: Login, Logout, Usuarios y Roles (Parcial)

### Roles del Sistema

| Rol | Ubicación | Descripción |
|-----|-----------|-------------|
| **Cliente** | N/A | Usuario final, ve sus paquetes, tracking, facturas |
| **Administrador** | Ambas | Acceso total al sistema |
| **Supervisor de Miami** | Miami | Supervisa recepción, pre-alertas, re-empaque, digitadores en Miami |
| **Digitador Miami** | Miami | Opera la pantalla de Etiquetar/Digitar: escanea tracking, ingresa datos de paquetes, imprime etiquetas |
| **Supervisor de Caja** | Honduras | Supervisa pagos y cajeros en Honduras |
| **Supervisor Prefactura** | Honduras | Supervisa generación de prefacturas |
| **Cajeros** | Honduras | Procesan pagos de clientes |
| **SAC** (Servicio al Cliente) | Honduras | Atención al cliente, consultas, reclamos |
| **Entrega y Despacho** | Honduras | Gestiona entregas finales al cliente |

### Pendiente por definir en conversación:
- [ ] Permisos específicos por rol (qué módulos ve cada uno)
- [ ] Flujo de creación de usuarios (quién crea a quién)
- [ ] Autenticación (email/password, 2FA?)
- [ ] Manejo de sesiones y logout
- [ ] Roles múltiples por usuario? (ej: un supervisor que también es cajero)
- [ ] Ubicación por usuario (Miami vs Honduras)

---

## Aclaraciones del Cliente (Q&A)

### Consolidación de paquetes que llegan en días diferentes

**Pregunta:** Cuando el cliente consolida varios paquetes en uno, ¿cómo se maneja si los paquetes llegan en días diferentes? ¿Se espera a que lleguen todos o se van agregando?

**Respuesta:** Actualmente se recepcionan/digitalizan y se envían de acuerdo al tipo de envío solicitado. La consolidación se hace en SPS (San Pedro Sula) y se le notifica al cliente cuando ya están todos en SPS.

**Implicación para el sistema:**
- Los paquetes se etiquetan y envían individualmente en Miami sin esperar consolidación
- La consolidación física ocurre en la bodega de Honduras (SPS), no en Miami
- El sistema debe permitir agrupar paquetes de una misma pre-alerta consolidada al llegar a Honduras
- Se notifica al cliente cuando todos los paquetes de su consolidado están en SPS

### Tipos de envío: configurables o fijos

**Pregunta:** Las combinaciones CER/CKA/CEM/CKM/EXP son fijas o el admin puede crear nuevos tipos? Hay precios diferentes por cada uno?

**Respuesta:** Sí, el administrador puede crear a futuro nuevos servicios o productos. Sí tienen precios diferentes y se manejan en Dólares y Lempiras con una tasa de cambio en el sistema que convierte las tarifas de dólar a Lempiras automáticamente.

**Implicación para el sistema:**
- Los tipos de envío deben ser un catálogo administrable (CRUD para admin), no hardcoded
- Cada tipo de envío tiene su propia tarifa en USD
- El sistema convierte automáticamente USD → LPS usando la tasa de cambio configurada (ya existe en tabla `configuraciones`)
- Modelo TipoEnvio necesita campos de precio (precio_libra, precio_volumen, etc.)

### Límite de trackings por pre-alerta

**Pregunta:** ¿Hay un máximo de trackings que un cliente puede agregar a una sola pre-alerta?

**Respuesta:** No, no hay límite.

**Implicación para el sistema:**
- No se necesita validación de cantidad máxima en la relación PreAlerta → Trackings
- Considerar paginación/scroll en la UI si un cliente agrega muchos trackings

### Edición de pre-alertas después de recibido

**Pregunta:** ¿Puede el cliente editar una pre-alerta después de que Miami ya recibió el paquete? ¿O se bloquea?

**Respuesta (Abril 2026, matriz refinada):** Las reglas dependen de si el paquete está **vinculado** (ya recibido en Miami) o **no vinculado** (aún en estado PRE_ALERTA), combinado con el tipo de servicio origen y el estado del paquete físico.

**Matriz de reglas — Mover / Eliminar paquete de una pre-alerta:**

| Estado del Paquete | Origen CONSOLIDANDO (EXP/CER/CEM) | Origen SIN CONSOLIDAR (EXP/CER/CEM) | Origen CKA/CKM |
|---|---|---|---|
| **PRE_ALERTA** (no vinculado, sin paquete físico) | Mover a cualquier PA consolidando CER/CEM/EXP · editar tracking/descripción · eliminar PAP | Igual | Igual |
| **recibido_miami** (vinculado) | Mover a PA consolidando del mismo tipo · eliminar PAP (el paquete queda en bodega) | Igual | BLOQUEADO |
| **empacado** (vinculado) | Igual que fila anterior | Igual | BLOQUEADO |
| **enviado_honduras** (vinculado) | Igual que fila anterior | Igual | BLOQUEADO |
| **en_aduana** en adelante (incluye disponible_entrega, pre_facturado, facturado, en_reparto, entregado, retenido, retornado, desechado, anulado) | BLOQUEADO | BLOQUEADO | BLOQUEADO |

**Notas de Consolidación (`notas_grupo`):** Editables mientras la PA esté consolidando Y ningún paquete vinculado haya llegado a `en_aduana` o posterior. Si cualquier paquete avanza a `en_aduana`+, las notas quedan en modo solo lectura.

**Historial de movimientos:** Al mover un paquete entre pre-alertas, las notas del grupo origen (`notas_grupo`) se incluyen como sufijo en las entradas del historial de ambas PAs (origen y destino). Esto permite conservar el contexto sin mutar las `notas_grupo` del destino.

**Eliminar paquete vinculado:** Cuando el cliente elimina un PAP vinculado (permitido sólo en recibido_miami/empacado/enviado_honduras y fuera de CKA/CKM), se destruye únicamente la fila de unión. El `Paquete` físico permanece intacto en la bodega y sigue siendo visible desde las vistas admin.

**Implicación para el sistema:**
- Lógica de permisos de edición depende de: tipo de servicio origen + estado del paquete vinculado + si el paquete está o no vinculado
- Reglas de negocio (controller `Cuenta::PreAlertasController`):
  - `puede_mover?(pap)` → false si PA finalizada; si `pap.paquete_id` presente exige estado en `ESTADOS_MOVIBLES` y origen no CKA/CKM; si no vinculado → true siempre
  - `puede_eliminar?(pap)` → misma lógica que `puede_mover?`
  - `PreAlerta#notas_editables?` → `consolidando?` y ningún paquete vinculado en `ESTADOS_QUE_BLOQUEAN_NOTAS` (en_aduana hacia adelante)
- `ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras]`
- `ESTADOS_QUE_BLOQUEAN_NOTAS = %w[en_aduana disponible_entrega pre_facturado facturado en_reparto entregado retenido retornado desechado anulado]`
- La UI oculta botón "Mover" / "Eliminar" cuando no aplica; muestra confirmación larga ("el paquete físico permanece en nuestra bodega...") para eliminaciones vinculadas

### Cancelación de pre-alertas con paquetes recibidos

**Pregunta:** ¿Puede el cliente cancelar/borrar una pre-alerta que ya tiene paquetes recibidos en Miami?

**Respuesta:** No.

**Implicación para el sistema:**
- Una pre-alerta solo puede cancelarse/eliminarse si todos sus paquetes están en estado **Pre-Alerta** (ninguno recibido aún)
- Una vez que al menos un paquete pasa a estado **Recibido**, la pre-alerta se bloquea contra cancelación
- La UI debe ocultar/deshabilitar el botón de cancelar cuando hay paquetes recibidos
- Considerar soft-delete (marcar como cancelada) en vez de hard-delete para auditoría

### Notificaciones al cliente durante el flujo

**Pregunta:** ¿Qué notificaciones recibe el cliente durante el flujo? (email, WhatsApp, push?) ¿En qué momentos exactos?

**Respuesta:**

**Email:**
- Al crear pre-alerta
- Al actualizar pre-alerta
- Al recibir paquete en Miami
- Cuando está disponible para entrega
- Al crear casillero (envío de información del casillero)
- Recordatorio los domingos: paquetes no reclamados de la semana antepasada

**WhatsApp:**
- Cuando está disponible para entrega
- Futuro: inscripción del cliente vía WhatsApp (queda registrado y aprobado para recibir información general)

**SMS:**
- Cuando está disponible para retiro, solo si el cliente NO está inscrito para recibirlo por WhatsApp (fallback)

**Push notifications:**
- En todos los cambios de estado: Pre-Alerta → Recibido en Miami → Enviado → Aduana → Disponible para retiro
- Recordatorio de paquetes no reclamados

**Implicación para el sistema:**
- Modelo `Notificacion` o sistema de eventos que dispare notificaciones según cambio de estado del paquete
- Canales de envío: email (siempre), WhatsApp (si inscrito), SMS (fallback si no WhatsApp), push (siempre)
- Preferencia de canal por cliente: campo `whatsapp_inscrito` o similar
- Job de recordatorio dominical (Solid Queue cron): buscar paquetes disponibles no reclamados con más de 1 semana
- Integración WhatsApp API necesaria para: notificaciones + flujo de inscripción
- La inscripción vía WhatsApp es un flujo nuevo (no existe en sistema actual)

### Paquetes sin pre-alerta (mayoría de casos)

**Pregunta:** ¿Qué pasa cuando llega un paquete a Miami que NO tiene pre-alerta? ¿Se crea una automáticamente? ¿Se asigna al cliente por el tracking?

**Respuesta:** Se le asigna en Etiquetar/Digitación. Allí es donde se escanea y se llena manualmente toda la información requerida. Son la mayoría de los casos.

**Implicación para el sistema:**
- La mayoría de paquetes NO tienen pre-alerta previa — el flujo principal es digitación manual en Miami
- La pantalla Etiquetar es el punto de entrada principal del sistema, no las pre-alertas
- No se crea pre-alerta automática; el paquete existe independiente sin pre-alerta asociada
- El digitador asigna el cliente manualmente (autocomplete por código)
- La vinculación paquete ↔ pre-alerta es opcional, no obligatoria
- Prioridad de desarrollo: Etiquetar (Fase 1) es más crítico que Pre-Alertas (Fase 2)

### Paquete con pre-alerta pero cliente equivocado

**Pregunta:** Si el tracking de DHL viene a nombre de "Maria" pero el cliente registrado es "Jorge", ¿cómo se resuelve?

**Respuesta:** Pendiente de aclaración — el cliente no estaba seguro de este escenario.

**Implicación para el sistema:**
- Escenario a resolver en fase de digitación/etiquetado
- Posiblemente requiere flujo de reasignación o corrección de cliente en el paquete
- Documentar cuando el cliente aclare el proceso

### Notas Miami vs Honduras (editabilidad)

**Pregunta:** Las notas del cliente, ¿son editables por el digitador? ¿O son read-only y solo el cliente/admin las modifica?

**Respuesta:** Son fijas. Solo el personal de la empresa las modifica: SAC, Admin, Supervisores, Auditoría.

**Implicación para el sistema:**
- Las notas del cliente NO son editables por el digitador Miami
- Roles con permiso de edición de notas: `admin`, `sac`, `supervisor_miami`, `supervisor_caja` (auditoría)
- El digitador las ve como read-only
- El cliente NO modifica notas (solo personal interno)

### Limpiar Vacías (pre-alertas/pre-facturas sin registros)

**Pregunta:** El botón "Limpiar Vacías" ¿elimina permanentemente o solo marca como anuladas? ¿Tiene confirmación?

**Respuesta:** Limpia pre-facturas, pre-alertas o todo lo que se crea automáticamente o manualmente sin registro alguno. Se sugiere crear un proceso automático que lo haga todos los días tipo 3am.

**Implicación para el sistema:**
- Crear job automático (Solid Queue cron) que se ejecute diariamente a las 3am
- El job elimina/anula registros vacíos: pre-alertas sin paquetes, pre-facturas sin líneas, etc.
- No requiere confirmación del usuario (es automático y solo afecta registros vacíos)
- Definir "vacío" para cada entidad: pre-alerta sin tracking, pre-factura sin líneas de detalle, etc.
- Posiblemente soft-delete (marcar como anulado) en lugar de eliminación permanente para auditoría

### Creado Por (registro de auditoría)

**Pregunta:** El campo "Creado Por" en la lista, ¿se refiere al cliente que la creó o al operador? Si el admin crea una pre-alerta por teléfono, ¿quién aparece?

**Respuesta:** Todo lleva registro de quién hizo qué. "Creado" indica si es el cliente o qué usuario interno la creó. En el log se registra cada vez que modifican y presionan botones del sistema.

**Implicación para el sistema:**
- Todos los modelos principales necesitan campos `creado_por_id` y `creado_por_tipo` (polimórfico: Cliente o User)
- Implementar sistema de auditoría/log: registrar cada acción (crear, modificar, cambiar estado, presionar botones)
- Modelo `AuditLog` o similar: `auditable_type`, `auditable_id`, `accion`, `usuario_id`, `usuario_tipo`, `cambios` (JSON), `created_at`
- Mostrar en la UI: "Creado por: Cliente Jorge Padilla" o "Creado por: Admin María López"
- Log accesible para roles de auditoría/admin

### Tareas y Re-empaque (pendiente de reunión)

**Pregunta:** ¿Quién asigna las tareas? ¿El digitador Miami al etiquetar? ¿El supervisor? ¿Se auto-asignan basado en el tipo de envío (si es CER = tarea de re-empaque automática)? ¿Re-empaque obligatorio u opcional? Si el cliente seleccionó "sin reempaque" pero el paquete necesita reempaque por tamaño, ¿se puede cambiar? ¿Quién autoriza?

**Respuesta:** Prefiere explicarlo en reunión directa. Pendiente de agendar.

**Implicación para el sistema:**
- El módulo de tareas/re-empaque requiere reunión dedicada antes de diseñar
- No implementar hasta tener las reglas claras
- Temas pendientes: asignación automática vs manual, autorización de cambios, flujo de aprobación

### Fotos del paquete

**Pregunta:** ¿Se toman fotos antes y después del re-empaque? ¿Son obligatorias?

**Respuesta:** Actualmente no se toma foto de nada. Quisiera foto del producto que llegó, posiblemente hasta unas 3 fotos.

**Implicación para el sistema:**
- Agregar fotos al modelo Paquete: hasta 3 fotos por paquete (del producto al llegar a Miami)
- Usar Active Storage para manejo de imágenes
- Las fotos se toman en el paso de digitación/etiquetado en Miami
- Considerar almacenamiento en la nube (S3/Cloudinary) para producción en Render
- No son del re-empaque (antes/después), sino del producto al ser recibido
- Definir si son obligatorias o opcionales (por ahora, opcionales)

### Pre-alertas creadas por servicio al cliente (asistencia)

**Aclaración del cliente:** La pre-alerta no solo la crea el cliente desde su portal. El personal de servicio al cliente también puede crear pre-alertas como asistencia (por ejemplo, cuando el cliente llama por teléfono).

**Roles que pueden crear pre-alertas:** SAC, Supervisor SAC, Admin, Auditor.

**Implicación para el sistema:**
- La pantalla de crear pre-alerta debe existir tanto en el portal del cliente como en el portal administrativo
- Roles con permiso de crear/editar pre-alertas: `sac`, `supervisor_sac`, `admin`, `auditor`
- Cuando la crea personal interno, el campo `creado_por` refleja al usuario interno (no al cliente)
- **Nuevos roles detectados** no incluidos en la lista original:
  - `supervisor_sac` — supervisar equipo de servicio al cliente
  - `auditor` — auditoría del sistema (también mencionado en Q9 para edición de notas)
- Actualizar enum de roles del modelo User para incluir estos roles adicionales

### Tracking y duplicados (pendiente de reunión parcial)

**Pregunta 15:** 1 tracking = múltiples cajas (DHL): ¿Cómo aparece esto en la pre-alerta del cliente? ¿Ve 1 tracking o 5 líneas separadas? ¿Quién define cuántas cajas son?

**Respuesta:** Eso lo detecta el personal al ingresarlo. El cliente está analizando cambiar la forma de manejarlo y prefiere explicarlo en llamada.

**Pregunta 16:** Tracking reciclado/duplicado: ¿El sistema bloquea la entrada o solo muestra una alerta y deja continuar?

**Respuesta:** Quiere que el sistema muestre un modal informando que el tracking ya está asignado, mostrando la información existente, y dando la opción de: (a) es un nuevo registro, o (b) es una actualización del existente.

**Implicación para el sistema:**
- El manejo de 1 tracking → múltiples cajas necesita reunión dedicada antes de diseñar el modelo
- Para tracking duplicado/reciclado: implementar modal de detección al ingresar tracking
  - Buscar tracking existente en BD
  - Si existe: mostrar modal con datos del paquete/pre-alerta existente
  - Opciones en el modal: "Crear nuevo registro" o "Actualizar existente"
  - Aplica tanto en pre-alertas del cliente como en digitación Miami
- DHL específicamente reutiliza trackings y envía múltiples cajas con el mismo número

### Transición Pre-Alerta → Pre-Factura

**Pregunta 17:** ¿Cuándo se genera la pre-factura? ¿Automáticamente al recibir y pesar en Miami? ¿O manualmente por el supervisor?

**Respuesta:** El pesaje y medición se hace en Honduras (no en Miami). Se agrega manualmente la información a la pre-factura. Se recomienda visita al sitio para ver todo el proceso.

**Pregunta 18:** Paquetes parciales: Si una pre-alerta tiene 3 trackings pero solo llegaron 2, ¿se puede pre-facturar parcial? ¿O se espera a que lleguen todos?

**Respuesta:** Toda pre-factura que tenga una pre-alerta de consolidación se va alimentando poco a poco. Hasta completar todas se le notifica al cliente. El cliente quiere que esta parte sea semi-dirigida ("como el ganado") y de apoyo al personal: notificando automáticamente si tiene consolidado, etc. Este es un tema largo que requiere más discusión.

**Pregunta 19:** Cambio de tipo de envío: Si el cliente pidió CER (aéreo) pero después quiere cambiar a CEM (marítimo), ¿en qué punto del flujo se permite ese cambio? ¿Eso es lo que significa el flag amarillo "Solicitó Cambio de Servicio"?

**Respuesta:** El cliente puede cambiar el tipo de envío únicamente en estado de pre-alerta. Después de ese estado, solo se puede vía SAC: el cliente se comunica con Miami y se inicia un proceso de localización y cambio. Este proceso casi siempre lleva un costo adicional. El cliente quiere que se realice automáticamente o que el personal de Miami marque algo para que se agregue el cobro en la pre-factura al seleccionar dicho paquete. Y sí, el flag amarillo "Solicitó Cambio de Servicio" es para este escenario.

**Implicación para el sistema:**
- **Pesaje/medición en HN, no en Miami** — corrige la suposición anterior; el flujo de pre-factura es en Honduras
- **Pre-factura parcial para consolidaciones:** la pre-factura se alimenta incrementalmente a medida que llegan paquetes
  - Necesita estado parcial: "En espera de paquetes" vs "Completa"
  - Notificación automática al cliente cuando se completa la consolidación
  - Apoyo al digitador: alertas de consolidaciones pendientes
- **Cambio de tipo de envío:**
  - Estado pre-alerta: el cliente lo cambia libremente desde su portal
  - Post pre-alerta: solo vía SAC → proceso de localización + cambio
  - Agregar campo `solicito_cambio_servicio: boolean` al paquete (flag amarillo)
  - Al marcar el flag, generar cargo automático en la pre-factura
  - Modelo `CargoAdicional` o línea extra en pre-factura: concepto "Cambio de servicio", monto configurable
- **Visita al sitio HN** recomendada para entender flujo completo de pre-facturación

---

## Próximos Pasos

1. **Conversación 2:** Login, Logout, Creación de usuarios y roles — por documentar
2. **Conversación 3:** Pendiente — visita al cliente
3. **Conversación 4:** Pendiente — visita al cliente
4. Después de las 4 conversaciones: crear plan de implementación completo por módulo
