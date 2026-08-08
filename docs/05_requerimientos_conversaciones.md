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

#### 5.1 Flow guiado al detectar duplicado (confirmado por Yusef, 2026-04-25)

Cuando el digitador escanea/ingresa un tracking que ya existe en el sistema, el sistema **interrumpe el flujo** y muestra un modal con dos opciones explícitas:

**Opción A — "Es actualización de información"**
- Caso típico: error de captura previo (tipo de envío equivocado, cliente equivocado).
- El sistema **carga la recepción original en modo edit** — el digitador no crea un paquete nuevo, edita el existente.
- Se mantiene el mismo `numero_recepcion`, mismo tracking, mismo paquete físico. Cambia los campos que el digitador necesite corregir.

**Opción B — "Es un tracking repetido (duplicado real)"**
- Caso típico: dos paquetes físicos distintos comparten el mismo tracking impreso (paquetería que recicla números).
- El sistema **agrega una letra al tracking** del nuevo paquete, conservando el original intacto:
  - 1° con ese tracking: `1ZHGR123451234` (sin sufijo).
  - 2°: `1ZHGR123451234A`.
  - 3°: `1ZHGR123451234B`.
  - 4°: `1ZHGR123451234C`.
  - … y así sucesivamente.
- Cada uno es un paquete distinto en BD, con su propio `numero_recepcion`, cliente, etc.

**Decisiones tomadas (Yusef, 2026-04-25):**
- **Alcance del modo "actualización":** el digitador puede editar **cualquier campo** del paquete original (sin restricción). El caso típico es corregir tipo de envío o cliente, pero pueden cambiar lo que ocupen — el sistema simplemente carga la recepción original en el form de edit ya existente.
- **Comportamiento al pasar `Z` (27° duplicado):** parar y pedir intervención manual del supervisor. En la práctica nunca se llega a `Z` (la mayoría de duplicados son 1-2). Si en el futuro se vuelve común, se puede extender a `AA`, `AB`, … en un PR posterior.
- **Auditoría:** por ahora no se agrega bitácora explícita. El `updated_at` de Rails y los logs estándar son suficientes para trazabilidad. Si más adelante el supervisor quiere reportes específicos de duplicados, se agrega como follow-up.

### 6. Numeración de Recepción (`numero_recepcion`) — Formato Anual

**Contexto:** Hoy el formato es `RM-042424` (prefijo de sucursal `+` 6 dígitos secuenciales corridos para siempre, vía PostgreSQL sequence por sucursal).

**Formato confirmado (Yusef, 2026-04-25):** `RM0002026000001`

Estructura:
- **Prefijo de sucursal** (1-4 letras mayúsculas, configurable por sucursal vía `codigo_recepcion_prefix`):
  - `RM` = Recibido Miami.
  - `SZN` = Sucursal Zerón (Honduras).
  - Otros prefijos se configuran al crear la sucursal.
- **`0002026`** = año en 7 dígitos zero-padded.
- **`000001`** = número de paquete del año, 6 dígitos zero-padded — **reinicia el 1° de enero**.

Ejemplos:
- `RM0002026000001` = primer paquete recibido en Miami en 2026.
- `SZN0002026000042` = paquete #42 recibido en sucursal Zerón en 2026.
- `RM0002027000001` = primer paquete del 2027 (contador reinicia).

**Implicaciones:**
- La PostgreSQL sequence anterior (corrida para siempre por sucursal) se reemplaza por contador `(sucursal_id, anio)` con lock atómico.
- Backfill: los `numero_recepcion` históricos quedan en formato viejo y los nuevos usan el formato anual (coexisten).
- Búsqueda ILIKE encuentra ambos formatos sin cambios adicionales.

**Estado:** ✅ Implementado en PR-A (#79).

#### 6.1 Sub-etiquetas: división de un tracking en varios paquetes (1/3, 2/3, 3/3)

**Nota de Yusef (2026-04-25):**
Cuando un mismo `tracking` se recibe físicamente como **varios bultos**, se divide en sub-etiquetas con notación `<n>/<N>`:
- 1/3, 2/3, 3/3 = un tracking dividido en 3 cajas.

**Dónde ocurre la división:**
- **Miami:** principal — al recibir el tracking se decide si se divide en N cajas.
- **Honduras:** ocurre en el contexto de la **pre-factura** (al agrupar trackings).

**Estado actual:** existe `paquetes.numero_caja` y `paquetes.cantidad_paquetes` en el modelo (módulo 36 — multi-caja DHL). Pendiente confirmar:
- Si la notación `<n>/<N>` se imprime en la etiqueta física, en el `numero_recepcion`, o en una columna aparte.
- Si los N paquetes comparten el mismo `numero_recepcion` con sufijo o tienen `numero_recepcion` distinto cada uno.
- UX en Etiquetar: ¿el digitador indica "dividir en 3 cajas" y el sistema crea 3 paquetes automáticamente?

**Preguntas abiertas para el cliente:**
- ¿Se reusa la columna `cantidad_paquetes` (existente) o necesitamos nuevas columnas (`numero_caja_secuencia`, `total_cajas_tracking`)?
- ¿La etiqueta impresa muestra `1/3` como texto separado o forma parte del `numero_recepcion`?
- ¿En Honduras, la división en pre-factura ya funciona en el sistema actual (Roger) o también hay que diseñarla?

### 7. Fotos de Paquetes en Recepción (Miami)

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

### 8. Re-empaque y Reducción de Volumen

**Contexto:** Los operadores en Miami reducen el tamaño de las cajas manualmente (cortan cartón) para bajar el volumen cobrado al cliente. Esto es un diferenciador vs. la competencia.

**Ejemplo:** Caja de 18x15x14 → recortada a 18x15x6 = ahorro significativo en volumen.

**Fórmula volumen:** `largo x ancho x alto / 166 = libras volumétricas`

**Requerimientos:**
- [ ] Registrar dimensiones originales y finales del paquete
- [ ] Calcular ahorro en volumen automáticamente
- [ ] Mostrar al cliente el beneficio del re-empaque (antes/después)

### 9. Patrón de UI Consistente + Búsquedas y Filtros

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

### 10. Mejoras Generales Identificadas

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

**Acciones de guardado (portal cliente, Abril 2026):**
- **Autosave**: activo en pre-alertas consolidando. PATCH con `autosave=true` tras 1.5s de debounce en cualquier input.
- **Guardar (F8)**: botón/atajo que fuerza el flush del autosave pendiente (cancela debounce, espera respuesta) y muestra un modal de confirmación estilizado ("¡Tus cambios fueron guardados!") con auto-dismiss a 3s. Visible en ambos modos.
- **Finalizar Consolidación (F9)**: solo en consolidando. Espera el autosave en vuelo y marca la PA como finalizada.

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

| Atajo | Acción | Stimulus handler (cliente) |
|-------|--------|-----------|
| F2 / Escape | Cancelar edición y volver al listado | `pre_alerta_editor#cancel` |
| F6 | Agregar una fila de paquete en el editor | `pre_alerta_editor#addPaquete` |
| F8 | Guardar: flush de autosave pendiente + modal "Guardado" | `pre_alerta_editor#save` |
| F9 | Finalizar Consolidación (solo consolidando) | `pre_alerta_editor#finalizar` |

**Nota:** En el portal cliente, los atajos están bindeados globalmente en `pre_alerta_editor_controller#handleKeydown`. La vista admin/logística (operadores Miami) es un sistema legacy con sus propios bindings.

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
| **recibido_miami** (vinculado) | Mover a PA consolidando del mismo tipo · **eliminar BLOQUEADO desde el portal cliente** | Igual | BLOQUEADO |
| **empacado** (vinculado) | Mover a PA consolidando del mismo tipo · **eliminar BLOQUEADO desde el portal cliente** | Igual | BLOQUEADO |
| **enviado_honduras** (vinculado) | Mover a PA consolidando del mismo tipo · **eliminar BLOQUEADO desde el portal cliente** | Igual | BLOQUEADO |
| **en_aduana** en adelante (incluye disponible_entrega, pre_facturado, facturado, en_reparto, entregado, retenido, retornado, desechado, anulado) | BLOQUEADO | BLOQUEADO | BLOQUEADO |

**Notas de Consolidación (`notas_grupo`):** Editables mientras la PA esté consolidando Y ningún paquete vinculado haya llegado a `en_aduana` o posterior. Si cualquier paquete avanza a `en_aduana`+, las notas quedan en modo solo lectura.

**Historial de movimientos:** Al mover un paquete entre pre-alertas, las notas del grupo origen (`notas_grupo`) se incluyen como sufijo en las entradas del historial de ambas PAs (origen y destino). Esto permite conservar el contexto sin mutar las `notas_grupo` del destino.

**Eliminar paquete vinculado (Abril 2026):** El cliente **ya no puede** desvincular un PAP vinculado desde el portal, independientemente del estado o tipo de envío. El ícono de basurero se oculta para cualquier PAP con `paquete_id.present?`. El endpoint `eliminar_paquete` responde con alert "No se puede eliminar: el paquete ya fue recibido en nuestra bodega" como red de seguridad.

**Auto-soft-delete de pre-alerta vacía:** Si al mover o eliminar un PAP la pre-alerta queda sin paquetes, se hace `soft_delete!` automáticamente:
- Callback `after_destroy_commit :soft_delete_pre_alerta_if_empty` en `PreAlertaPaquete` cubre `destroy!` directo, `accepts_nested_attributes_for` y el autosave.
- `mover_paquete` controller hace soft-delete manual (el PAP se actualiza, no se destruye).
- Antes de borrar siempre se pide confirmación (modal estilizada, ver sección UI).

**Implicación para el sistema:**
- Lógica de permisos de edición depende de: tipo de servicio origen + estado del paquete vinculado + si el paquete está o no vinculado
- Reglas de negocio (controller `Cuenta::PreAlertasController`):
  - `puede_mover?(pap)` → false si PA finalizada; si `pap.paquete_id` presente exige estado en `ESTADOS_MOVIBLES` y origen no CKA/CKM; si no vinculado → true siempre
  - `puede_eliminar?(pap)` → **false si PA finalizada o si `pap.paquete_id.present?`**; true solo para PAPs no vinculados
  - `PreAlerta#notas_editables?` → `consolidando?` y ningún paquete vinculado en `ESTADOS_QUE_BLOQUEAN_NOTAS` (en_aduana hacia adelante)
- `ESTADOS_MOVIBLES = %w[recibido_miami empacado enviado_honduras]` (aplica solo a `puede_mover?`)
- `ESTADOS_QUE_BLOQUEAN_NOTAS = %w[en_aduana disponible_entrega pre_facturado facturado en_reparto entregado retenido retornado desechado anulado]`
- La UI oculta botón "Mover" / "Eliminar" cuando no aplica
- Las confirmaciones usan modal estilizada (`shared/_confirm_modal` + `confirm_modal_controller`); `Turbo.setConfirmMethod` está sobreescrito para que `data-turbo-confirm` renderice el modal en vez del `window.confirm` nativo; `window.cecConfirm(message, { title, confirmLabel, danger })` está disponible globalmente para confirmaciones desde JS

### Buscar Paquetes (Agregar a la pre-alerta actual)

Modal accesible desde el botón "Buscar Paquetes" en el editor. Permite al cliente agregar paquetes **sueltos** (recibidos en bodega, sin pre-alerta) y, cuando aplica, **jalar** paquetes vinculados desde otras pre-alertas del mismo cliente.

**Reglas (matriz abril 2026):**

| PA destino | Sueltos | Vinculados de otra PA |
|---|---|---|
| CONSOLIDANDO (EXP/CER/CEM) | ✅ mismo tipo, estado en `ESTADOS_MOVIBLES` | ✅ origen consolidando del mismo tipo, no CKA/CKM |
| SIN CONSOLIDAR (EXP/CER/CEM) | ✅ mismo tipo, estado en `ESTADOS_MOVIBLES` | ❌ bloqueado (destino debe ser consolidando) |
| CKA/CKM | ❌ bloqueado (single_package) | ❌ bloqueado |
| Finalizada | ❌ bloqueado | ❌ bloqueado |

**Implementación (`Cuenta::PreAlertasController`):**
- `puede_buscar?` → false solo si PA finalizada o tipo single_package (CKA/CKM).
- `candidatos_para_buscar` scope: siempre sueltos del `current_cliente` mismo tipo. Vinculados solo cuando el destino está `consolidando?` (y el origen es consolidando no CKA/CKM).
- `agregar_paquete` con mensajes específicos:
  - Tipo distinto → "El tipo de envío del paquete (X) no coincide con esta pre-alerta (Y)."
  - Estado fuera de `ESTADOS_MOVIBLES` → "Este paquete ya se encuentra en [estado] y no puede moverse. Por favor comuníquese con las oficinas de Compras Express."
  - Origen CKA/CKM → "No se puede jalar un paquete de una pre-alerta CKA/CKM."
  - Vinculado + destino sin-consolidar → "Para jalar un paquete desde otra pre-alerta, esta debe estar en modo Consolidando."
  - `RecordNotFound` (paquete de otro cliente, o inexistente) → "Paquete no encontrado." (protección por scope `current_cliente.paquetes`, el modal nunca expone paquetes de otros clientes).

### Validación de Tracking

El tracking debe ser alfanumérico + guiones, sin espacios ni símbolos especiales. Se auto-convierte a mayúsculas al guardar.

- **Server-side:** `PreAlertaPaquete` valida con `/\A[A-Z0-9-]+\z/` + callback `normalize_tracking` que uppercases.
- **Client-side (abril 2026):** inputs del editor (`_paquete_fields.html.erb`) y del wizard (`new.html.erb`) llevan `pattern="[A-Za-z0-9\-]+"` + `title="Solo letras, números y guiones. Sin espacios ni símbolos."` para feedback inmediato del browser antes del submit.

### Cancelación de pre-alertas con paquetes recibidos

**Pregunta:** ¿Puede el cliente cancelar/borrar una pre-alerta que ya tiene paquetes recibidos en Miami?

**Respuesta:** No.

**Implicación para el sistema:**
- Una pre-alerta solo puede cancelarse/eliminarse si todos sus paquetes están en estado **Pre-Alerta** (ninguno recibido aún)
- Una vez que al menos un paquete pasa a estado **Recibido**, la pre-alerta se bloquea contra cancelación
- La UI debe ocultar/deshabilitar el botón de cancelar cuando hay paquetes recibidos
- **Soft-delete automático (Abril 2026):** si la pre-alerta queda sin PAPs tras mover o eliminar el último, se marca `deleted_at` automáticamente (callback `after_destroy_commit` en `PreAlertaPaquete` + soft-delete manual en `mover_paquete` controller). El job `CleanEmptyPreAlertasJob` sigue activo para limpieza retroactiva (PAs vacías con 30+ días)

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

## Conversación 3 (2026-04-29): Detalle de Paquete Interno + Warehouse Receipt

Contexto: Yusef envió spec completa para el rediseño de la vista detalle/edit del paquete y de la etiqueta que ya imprimimos como Warehouse Receipt. Sigue 17 preguntas pendientes con respuestas parciales.

### Decisiones de arquitectura confirmadas (Jorge + Yusef)

- **`numero_recepcion` compartido** entre las N cajas del split (madre único). Las cajas se distinguen por `numero_caja`. Formato `RM0002026000001` (15 chars) confirmado — no usar el formato `RM2026ZN000000001` del WR sample.
- **`WarehouseReceipt` como modelo separado** (no enriquecer `Paquete`). `has_many :packages`. El `numero_recepcion` actual de `paquetes` migra a `warehouse_receipts.receipt_number`.
- **`Supplier` (Proveedor)** modelo nuevo con código manual al crear, CRUD admin. Reemplaza el campo `paquetes.proveedor` (string libre actual).
- **`Agent`** modelo nuevo, opcional, CRUD admin. Aparece en el WR sample (ej. `CORPORACION KARSAM`).
- **`Terms`** (T&C) con texto genérico inicial (en/es), versionable. Cada WR congela la versión activa para auditoría.
- **Audit log con `paper_trail` gem** para `Paquete`, `Cliente`, `PreAlerta`, `Manifiesto`, `Venta`, `PreFactura`, `Entrega`. Sin implementación custom.

### Respuestas confirmadas por Yusef (PR-D1: estados, fechas, audit log)

#### A. Estado "Disponible para retiro" programado

La fecha programada se llena al **crear pre-factura en Honduras** (UI con: guía de manifiesto, fecha de trabajo/disponible, tipo de envío a procesar). Mientras espera la fecha programada, el paquete queda en estado `aduana`.

El día programado, el sistema **automáticamente**:
- Cambia el estado de todos los paquetes a `disponible_entrega`.
- Envía notificaciones al cliente: email + SMS/WhatsApp + push notification del navegador.
- Las notificaciones se envían **solo a partir de las 7am** (no de madrugada).

**Implementación:** job nocturno (cron a las 7am) que revisa los paquetes con `fecha_programada_disponible <= hoy` y dispara los cambios + notifs.

#### B. Re-modificación de fechas — política por campo

| Campo | Política |
|---|---|
| `fecha_pre_alerta` | Queda original — **NUNCA se sobrescribe** |
| `fecha_recibido_miami` | Se actualiza al cambio (sobrescribe) — **muestra indicador visual de "modificada"** cuando ya tuvo un cambio previo |
| `fecha_empacado` | Se actualiza al cambio (sobrescribe) |
| `fecha_enviado` | Se actualiza al cambio (sobrescribe) |
| `fecha_aduana` | Se actualiza al cambio (sobrescribe) |
| `fecha_consolidando` | Se actualiza al cambio (sobrescribe) |
| `fecha_disponible_entrega` | Se actualiza al cambio (sobrescribe) |

El **log/bitácora** conserva el histórico completo de cambios. Visible para roles definidos en sección G más abajo.

**Indicador visual de "fecha modificada"** (Yusef refinó 2026-04-29 spec): cuando una fecha (especialmente `fecha_recibido_miami`) ya fue actualizada al menos una vez, debe mostrarse algo que comunique que NO es la fecha original. Implementación: badge pequeño `(modificada)` o icono de lápiz junto a la fecha. Hover/click muestra "Original: <fecha previa> · Última edición por <iniciales> el <timestamp>".

**Implementación:** se aprovecha `paper_trail` (ya en plan PR-D1). Una `version` previa con `object_changes` que toque ese campo → el helper renderiza el indicador.

#### C. Iniciales del usuario

Campo nuevo `users.iniciales` editable al crear/editar el usuario en el CRUD admin. **NO calculado del nombre** (porque hay nombres repetidos y cada uno define su alias).

#### D. "En qué bodega está" = Sucursal + Sub-localidad

Bodega = sucursal. Sucursales operativas actuales:
- **Sucursal Col Zerón, SPS** (San Pedro Sula).
- **Sucursal Col Humuya, TGU** (Tegucigalpa).

Cada sucursal tiene **sub-localidades** (bodegas dentro de la sucursal o áreas tercerizadas) para simplificar búsquedas:
- `ZR01` = Zerón bodega central.
- `ZR02` = Zerón bodega CEM.
- (y así sucesivamente, configurables por admin).

Caso de uso: hay cargas que se almacenan en áreas terceras dentro/cerca de la sucursal y se identifican con sub-código.

**Implementación:**
- Modelo nuevo `SubLocalidad(sucursal_id, codigo, nombre, activo)`. CRUD admin.
- El paquete tiene **dos referencias a sucursal + sub-localidad**:
  - `sucursal_actual_id` + `sub_localidad_actual_id` — donde está físicamente. Se setea al escanear recepción.
  - `sucursal_destino_id` — a dónde va. Sale del manifiesto.

#### E. Fecha posible de entrega

- Tabla `tipos_envio` agrega columna `dias_estimados` (días típicos para ese tipo).
- Al crear el paquete: `fecha_posible_entrega = fecha_recibido_miami + tipo_envio.dias_estimados`.
- Al agregarse a un manifiesto: se actualiza con `manifiesto.fecha_envio + tipo_envio.dias_estimados` (afinar al implementar).
- **Override manual** opcional via columna `fecha_posible_entrega_override`.
- Roles autorizados a modificar manualmente: **admin + supervisor_miami + supervisor_prefactura**.

> Yusef adelantó: "más adelante quiero escanear paquete por paquete que se está empacando" — fuera de scope de PR-D1, pero tener el flow listo.

#### F. Recolecta — tarifa fija editable (pregunta 7, 2026-04-29 6:22pm)

- **No hay tabla de tarifas todavía** (porque siempre cambia por zona y cantidad).
- **Tarifa pre-establecida**: **$35 USD + ISV**, editable por el cajero al crear la recolecta.
- Implementación: configuración global (ej. `Empresa.tarifa_recolecta_default = 35.00 USD`), editable inline en el form al crear/asignar la recolecta del paquete.

#### G. Audit log — quién accede (pregunta 8, 2026-04-29 6:25pm)

**Admin + TODOS los supervisores** (`supervisor_miami`, `supervisor_caja`, `supervisor_prefactura`). Ya **NO** incluye SAC ni cajero ni digitador ni entrega_despacho.

> Esto refina la respuesta inicial del bloque B (que decía "SAC + Supervisores + Admin"). La nueva respuesta del 2026-04-29 6:25pm excluye SAC del audit log.

#### H. Notas permanentes del cliente — modal por área (pregunta 9, 2026-04-29 6:30pm)

Las "notas permanentes" se reusan/expanden:
- `clientes.notas_miami` (existente).
- `clientes.notas_honduras` (existente).
- `clientes.notas_caja` (**NUEVO**) — notas permanentes para el equipo de Caja en HND.
- `clientes.notas_sac` (**NUEVO**) — notas permanentes para el equipo de SAC.

**UI:** las notas se muestran como **MODAL** automático al abrir el paquete del cliente, filtradas por **área del usuario actual**:

| Rol que entra | Modal muestra |
|---|---|
| Digitador Miami / Supervisor Miami | `notas_miami` |
| Cajero / Supervisor Caja | `notas_honduras` + `notas_caja` |
| SAC | `notas_sac` |
| Supervisor Pre-Factura | `notas_honduras` + `notas_caja` |
| Admin | Todas |

#### I. Notas al cliente — flujo + plantillas (2026-04-29 follow-up)

**Estado actual:** "no está funcionando bien" — refactor necesario.

**Quién la ingresa/edita y cuándo:**
- **Etiquetar (Miami)** la INGRESA inicialmente al recibir el paquete. Esa nota viaja en el **correo de notificación al cliente** cuando llega la carga a Miami.
- **Pre-Factura (HND)** ADICIONA a la nota (no sobrescribe).
- **Caja + SAC** también adicionan (con las mismas plantillas que Pre-Factura).

**Nueva feature requerida — Plantillas de Notas al Cliente:**
- Yusef quiere un **catálogo de plantillas** porque hoy escriben información recurrente a mano.
- Cada plantilla: título + texto. Editable por admin.
- En el form de "Notas al cliente", botón "Insertar plantilla" → dropdown de plantillas → texto se pega al campo (no reemplaza, agrega).
- Las plantillas son compartidas entre Etiquetar / Pre-Factura / Caja / SAC (todos usan las mismas; sin segmentación por área para v1).

**Implementación (PR-D2):**
- Modelo nuevo `PlantillaNotaCliente(titulo, texto, activo, position)` + CRUD admin (`/plantillas-notas`).
- Stimulus `nota_template_picker_controller.js` que abre dropdown e inserta texto en el textarea.
- Campo `paquetes.notas_al_cliente` (text, ya existe en plan PR-D2 — confirmado).
- Mailer de notificación al cliente al recibirse en Miami: incluye `notas_al_cliente` actualizada en el cuerpo del correo.

#### J. Notas de retención — obligatorias + multi-select de motivos (pregunta 10, 2026-04-29 6:42pm)

- **Obligatorias** cuando el paquete pasa a estado `retenido` (validation a nivel de modelo).
- **Selección múltiple de motivos** desde un catálogo de plantillas (no solo texto libre).
- Caso de uso típico: paquete dañado, confirmar tipo de envío, mercancía prohibida, falta declaración, etc.

**Implementación (PR-D2):**
- Modelo nuevo `MotivoRetencion(nombre, descripcion, activo, position)` + CRUD admin (`/motivos-retencion`).
- Tabla join `paquete_motivos_retencion(paquete_id, motivo_retencion_id)` o columna array `paquetes.motivos_retencion_ids`. Decisión técnica al implementar — recomendable join table para preservar integridad referencial.
- Campo `paquetes.notas_retencion` (text, opcional pero útil para detalle libre adicional).
- Validation en `Paquete`: cuando `estado: retenido`, debe haber al menos 1 motivo seleccionado o `notas_retencion` presente.
- UI: cuando el digitador cambia estado a `retenido`, modal con checkboxes de motivos activos + textarea para detalle adicional.

#### K. Tercero — texto libre (revendedor flow) (preguntas 14-15, 2026-04-29)

**Tercero NO es un cliente registrado** — es **texto libre** porque son clientes de empresas terceras a CEC.

**Flujo de revendedor:**
- Quienes mantienen "terceros" son **revendedores** (negocios que usan CEC para mandar cargas a sus propios clientes).
- El **cliente principal (`cliente_id`)** es el revendedor (cliente registrado de CEC con su `clientes.codigo`).
- El **tercero** es el cliente final del revendedor — viene como **texto libre** en el form (nombre + opcionalmente teléfono/dirección).
- El paquete se procesa bajo el código del revendedor; la etiqueta y WR muestran el nombre del tercero como destinatario adicional.

**Implementación (PR-D3):**
- Columna nueva `paquetes.tercero_nombre` (string, nullable). Opcionalmente `tercero_telefono` / `tercero_direccion` si Yusef confirma alcance.
- **NO hay lupa de búsqueda** — solo input simple de texto libre.
- En el WR (`Consignee`): si `tercero_nombre` está presente, muestra "Cliente: [revendedor] · A nombre de: [tercero]".

#### L. Proveedor — dropdown con "Otros" + CRUD admin (pregunta 11, 2026-04-29)

- Dropdown de proveedores **pre-determinados** para facilitar el trabajo (Amazon, eBay, Walmart, Sams, Target, ENTREGA PERSONAL).
- Agregar opción **"OTROS"** que activa input de texto libre para cualquier proveedor no listado.
- Implementación: modelo `Proveedor(nombre, tipo enum [comercio | entrega_personal | otros], activo, position)` + CRUD admin para que el equipo agregue/modifique. Cuando el digitador elige "OTROS", se muestra textfield `paquete.proveedor_libre` (string) para capturar el nombre real.

#### M. ENTREGA PERSONAL — formulario + tracking interno auto (pregunta 12, 2026-04-29)

Cuando el digitador elige proveedor = `ENTREGA PERSONAL`, se activa un **formulario adicional** y el sistema **genera un tracking interno propio**.

**Formato del tracking interno:**
```
<CODIGO_SUCURSAL_RECIBIDO>-<YYYYMMDD>-<correlativo>
```

Ejemplos:
- `MIA-20260429-0001` (primero recibido en Miami el 2026-04-29 vía entrega personal).
- `MIA-20260429-0002` (segundo del mismo día).
- `SPS-20260429-0001` (recibido en sucursal SPS).

Componentes:
- **Sucursal donde se recibió** (sucursal Miami por default; otras si tenemos sub-bodegas en el extranjero).
- **Fecha de recibido** (`YYYYMMDD`).
- **Correlativo** del día por sucursal (4 dígitos, reinicia diariamente).

**Implementación:**
- Tabla nueva `entrega_personal_counters(sucursal_id, fecha, ultimo_numero)` con unique index `(sucursal_id, fecha)` (similar a `numero_recepcion_counters` pero por día, no por año).
- Helper `Paquete.generate_tracking_entrega_personal(sucursal:, fecha:)` que llama al counter y formatea el string.
- Cuando proveedor = `entrega_personal` y el digitador no provee tracking real, se genera automáticamente. Si el digitador provee uno (caso atípico), se respeta.

#### N. Re-imprimir Etiquetas Miami — preview con selección (pregunta 15, 2026-04-29 6:50pm)

Cuando el digitador clickea "Re-imprimir Etiquetas Miami" en un paquete dividido en N cajas:
- Aparece un **preview con las N etiquetas en miniatura**.
- El digitador **marca cuál(es) quiere imprimir** (checkboxes).
- Al imprimir, **una etiqueta por hoja** (cada una en su propia página).
- Ejemplo: paquete con 4 cajas → preview muestra etiquetas 1/4, 2/4, 3/4, 4/4 → digitador marca solo 2/4 y 3/4 → se imprimen esas dos (en 2 hojas).

**Implementación (PR-D4):**
- Nueva action `reimprimir_etiquetas` en `PaquetesController` que renderiza preview con todas las etiquetas hermanas del split.
- Vista con grid de tarjetas, cada una con checkbox + miniatura de la etiqueta.
- Botón "Imprimir seleccionadas" genera HTML print-friendly con `page-break-after: always` entre etiquetas → cada selección sale en página propia. `window.print()` se dispara automáticamente.
- Para paquetes single (no split), preview muestra 1 etiqueta + checkbox marcado por default (UX consistente).

#### Ñ. Imprimir Pre-Factura desde paquete — preview + copiar imagen (pregunta nueva, 2026-04-29 6:53pm)

Cuando el digitador clickea "Imprimir Pre-Factura" en el detalle de un paquete:
- Aparece un **preview** de la pre-factura completa (con todos sus paquetes — no solo el actual).
- Botón **Imprimir** disponible.
- También sirve para que el agente **copie la imagen** y la envíe al cliente por WhatsApp/correo.

**Implementación (PR-D4):**
- Vista de preview de la pre-factura (renderizar el PDF actual `PreFacturaPdf` en HTML print-friendly o mostrar el PDF en `<iframe>`).
- El botón ya existe en módulos de pre-factura — agregarlo al header del paquete linkeando a `pre_factura_path(@paquete.pre_factura)` con `?preview=true`.
- Para "copiar imagen": el preview es HTML por lo que el usuario puede capturar pantalla nativamente; sin lógica adicional.

#### O. Botón "Refrescar" — visual estilo Gmail (pregunta 16, 2026-04-29 6:54pm)

> "solo lo ocupamos para actualizar, pero lo que busco es un boton de actualizar (mas que todo en el web app que hace google)"

Es solo un **botón visual con icono de refresh** (↻) que recarga la página, equivalente a F5 pero accesible con un click. UX similar al botón de "actualizar" de Gmail.

**Implementación (PR-D4):**
- `ButtonComponent` con `icon: "arrow-path"` (heroicon de refresh circular).
- `href: request.fullpath` o `data-action="click->refresh#reload"` con un Stimulus controller mínimo que hace `location.reload()`.
- Sin lógica especial — solo recarga la página completa.

#### P. F2 = limpieza de parámetros (universal, 2026-04-29 6:54pm)

Yusef pidió que la tecla **F2** sirva para **limpiar los parámetros del formulario actual** en todos los módulos del sistema (ya respondido — universal).

Hoy F2 ya existe en `/etiquetar` y `/paquetes` (limpia búsqueda + foco al input). Necesitamos extenderlo a TODOS los formularios y listados con filtros.

**Implementación (PR-D-F2 separado, futuro o como parte de PR-D1):**
- Stimulus controller `f2_clear_controller.js` reutilizable que escucha global F2 y resetea el form/filtros del scope al que se aplica.
- Aplicar en: pre_facturas, ventas, manifiestos, entregas, ingresos_caja, egresos_caja, recibos, notas_debito, notas_credito, cotizaciones, proformas, financiamientos, clientes, usuarios, sucursales (cualquier index con filtros).
- Mantener el F2 actual en etiquetar/paquetes intacto.

#### Q. Carrier — FK al modelo `Carrier` (pregunta 13, 2026-04-29)

`paquetes.expedido_por` (string libre actual) se convierte en FK `paquetes.carrier_id` que referencia al modelo `Carrier` ya existente (UPS, USPS, DHL, FedEx).

**Implementación (PR-D3):**
- Migración: `add_reference :paquetes, :carrier, foreign_key: true`. Backfill: best-effort matching del string `expedido_por` contra `carriers.nombre`/`carriers.codigo`. Mantener el string actual durante un periodo de transición.
- En el form, dropdown con los carriers activos.

#### R. Manifiesto formato anual `MM2026000001` — incluir en PR-D1 (pregunta 17, 2026-04-29)

Yusef confirmó que el cambio de formato del manifiesto va **junto con PR-D1** (estados/fechas/audit log) — no PR aparte.

Formato análogo a `numero_recepcion` pero para manifiesto:
- `M` = Manifiesto.
- `M` = Miami (o `H` para Honduras según sucursal del manifiesto).
- `2026` = año (4 dígitos).
- `000001` = correlativo del año.
- Ejemplo: `MM2026000001`.

**Implementación (PR-D1):**
- Tabla nueva `manifiesto_counters(sucursal_id, anio, ultimo_numero)` similar a `numero_recepcion_counters`.
- `Manifiesto#generate_numero` genera el número en este formato al crear.
- `manifiestos.numero` queda como string. Backfill opcional para manifiestos viejos.

#### S. Segundo tracking (2do tracking) — agregado 2026-04-29

**Contexto:** muchos paquetes llegan con **2 números de seguimiento**. El proveedor le da UNO al cliente que crea la pre-alerta con ese tracking, pero el paquete físicamente llega con un tracking DIFERENTE. Eso complica:
- Vincular pre-alerta ↔ paquete (porque los strings no matchean).
- Comunicarle al cliente cuando pregunta por el suyo (el cliente conoce solo uno de los dos).

**Solución:**
- Nueva columna `paquetes.tracking_secundario` (string, nullable, indexed).
- En el form de etiquetar/edit del paquete: input opcional adicional debajo del tracking principal.
- **Vinculación de pre-alertas** (`PreAlertaPaquete.link_tracking!`) ahora intenta matchear contra `paquetes.tracking` **O** `paquetes.tracking_secundario`. Misma lógica al crear paquete: si el tracking de la pre-alerta no aparece como principal, el digitador captura el principal (físico) + el de la pre-alerta como secundario, y el sistema vincula.
- **Búsqueda** (`Paquete.buscar` scope) incluye `tracking_secundario` en el ILIKE.
- WR + etiquetas: muestran tracking principal; opcionalmente debajo "Alt: <secundario>" si hay.

**Implementación (PR-D1):** una columna más en la migración de PR-D1 + ajustes mínimos en `Paquete::buscar` y `PreAlertaPaquete.link_tracking!` + form input.

### Preguntas del bloque PR-D — todas resueltas

- 14b. **Empresa de transporte (ej. EPN = Pronto Cargo)** cuando un paquete cambia de manifiesto. ✅ **Resuelta (Yusef):** se **hereda del manifiesto actual**. No se duplica el dato en `paquetes` — si el paquete cambia de manifiesto, muestra la empresa nueva.
- 15. Re-imprimir etiquetas: ¿todas las cajas o solo la actual? ✅ **Resuelta:** modal de preview con **checkboxes de todas las cajas hermanas**, preseleccionadas por defecto; el digitador desmarca las que no necesita. Una etiqueta por hoja.
- 16. Botón "Refrescar": ¿F5 o algo específico? ✅ **Resuelta (Yusef, opción B):** refresco **granular vía Turbo Frame**, no F5 — recarga solo la zona dinámica sin perder el scroll. Implementado con `turbo_frame_tag "paquete_dynamic", target: "_top"` + `data: { turbo_frame: "paquete_dynamic" }` en el botón.
- 17. Manifiesto formato `MM2026000001`. ✅ **Resuelta e implementada** en PR-D1.d con el modelo `ManifiestoCounter` (contador por sucursal/año, análogo a `numero_recepcion_counters`).

---

## Conversación 4: Franja de contexto operativo (2026-08-01)

**Fuente:** dos hojas manuscritas de Yusef entregadas el 2026-08-01.

### El pedido, textual

> "Jalar: → Nombre → Tareas → y NOTAS."
> "**Tareas al lado derecho. Checkbox. Recopila el usuario.**"
> "Esto es en **Etiquetar** y en **Entrega Personal**."
> "Faltan → Notas: notas permanentes del cliente · notas internas · notas a cliente (es cualquier área que le quiera escribir al cliente) · notas de consolidados · notas especiales. Estas se ordenan por la jerarquía de la empresa."
> "Revisar sonidos en Tegus."

### El problema

El operario de Miami escanea un tracking y **no ve nada del contexto del cliente**. Para leer sus notas o sus instrucciones tiene que abrir el paquete en otra pantalla — y en `/etiquetar` el paquete todavía no existe. Resultado: las instrucciones del cliente ("el celular por Express, la ropa por marítimo") se pierden en la operación.

### Hallazgo: las notas ya existen, solo no se muestran

Las 5 categorías que Yusef lista como faltantes **ya están en la base de datos** desde PR-D2 (abril 2026). El problema no es que falten — es que ninguna se muestra durante la captura.

| Categoría (hoja de Yusef) | Columna real | Dónde se veía antes de PR-9 |
|---|---|---|
| Notas permanentes del cliente | `clientes.notas_miami` · `notas_honduras` · `notas_caja` · `notas_sac` | modal en `paquetes/show`, filtrado por rol |
| Notas internas | `paquetes.notas_internas` | `paquetes/show` + form |
| Notas a cliente | `paquetes.notas_al_cliente` + catálogo `PlantillaNotaCliente` | `paquetes/show` + form |
| Notas de consolidados | `paquetes.notas_consolidacion` (sync desde `pre_alertas.notas_grupo`) | `paquetes/show` |
| Notas especiales | `pre_alerta_paquetes.instrucciones` | `paquetes/show` |

En `/etiquetar` solo aparecía un banner ámbar con `notas_miami`, hardcodeado en el endpoint `/clientes/buscar`.

Lo mismo con las tareas: el modelo `Tarea` existe desde PR #66/#67 y ya registra `completado_por` + `completada_en`. Nunca se expuso al operario.

### Spec de la franja

Pantalla partida en `/etiquetar` y `/entrega_personal/new`: formulario a la izquierda, **franja de contexto pegada a la derecha** (en móvil cae debajo). La franja se llena sola cuando el operario selecciona un cliente o cuando el tracking escaneado matchea una pre-alerta.

Contiene, en este orden:

1. **Cliente** — nombre, código y categoría de precio. (El "Jalar → Nombre".)
2. **Tareas** — solo las abiertas y visibles para el área del usuario. Cada una con checkbox. Al marcarla:
   - se marca `realizada` con **quién** (`completado_por`) y **cuándo** (`completada_en`);
   - **desaparece de la franja para todos**, no solo para quien la marcó;
   - queda en el historial del paquete y en la bitácora `paper_trail`;
   - un supervisor puede reabrirla desde `/paquetes/:id/tareas` (no desde la franja).
3. **Notas** — las 5 categorías, en solo lectura.

### Decisiones confirmadas (Jorge, 2026-08-01)

1. **Origen de las tareas: cliente + pre-alerta.** Una tarea puede colgar de un cliente (`tareas.cliente_id`, nuevo) o de un paquete (`paquete_id`, ahora opcional). Las `instrucciones` que el cliente escribe en cada línea de su pre-alerta **se convierten en tareas reales** al guardarse, para que el digitador las vea al escanear.
2. **Al marcar el checkbox:** `realizada` + registro de quién y cuándo. Desaparece para todos. Reabrible por supervisor.
3. **"Jerarquía de la empresa" = orden por departamento:** Miami → Caja → Pre-Factura → SAC → Entrega.
4. **Alcance:** franja + notas + sonidos + documentación.

### Decisiones técnicas tomadas al implementar (PR-9)

Resueltas sin consultar por ser detalle de implementación; se documentan para dejar rastro.

- **Pre-Factura y Entrega no reciben columna de notas propia.** El orden confirmado nombra 5 áreas, pero el modelo tiene 4 columnas: Pre-Factura y Entrega leen ambas `notas_honduras`. Orden efectivo: **Miami → Caja → Honduras → SAC**. Partir `notas_honduras` en dos fragmentaría un dato que hoy las dos áreas comparten a propósito.
- **La franja es solo lectura.** Los campos de escritura (`notas_internas`, `notas_retencion`) ya viven en el formulario de la izquierda. La franja tiene un solo trabajo: dar contexto.
- **Las tareas de cliente son de un solo uso.** Lo que aplica "siempre" a un cliente son sus notas permanentes; una tarea se limpia y se cierra.
- **Nueva columna `tareas.bloquea_avance`.** `Paquete#no_advance_with_open_tareas` bloquea el avance de estado si hay tareas abiertas. Auto-crear tareas desde `instrucciones` habría congelado cualquier paquete cuya pre-alerta trajera instrucciones. Las tareas de origen `pre_alerta` nacen con `bloquea_avance: false`; las creadas a mano, `true` (y el backfill deja en `true` todo lo existente, así que el comportamiento actual no cambia).
- **Preferencia de sonido por usuario**, siguiendo el precedente de `tema` y `sidebar_position`.
- **`clientes/show` pasa a mostrar las 4 notas permanentes.** Hoy `notas_caja` y `notas_sac` se pueden editar pero nunca se ven — inconsistencia del mismo tema, corregida aquí.

### Sonidos — diagnóstico de "no suena en Tegus"

`audio_controller.js` sintetiza los tonos con Web Audio API (osciladores, sin archivos de audio). Dos causas:

1. **`AudioContext` suspendido.** Chrome lo crea en estado `suspended` hasta que hay un gesto del usuario. El controlador nunca llamaba `resume()`, y el `try/catch` de `_playTone` **se tragaba el error en silencio** — fallaba sin dejar rastro en consola.
2. **Volumen.** Onda seno pura con ganancia `0.3` es muy poco para una bodega ruidosa.

Corregido con `resume()` + unlock en el primer gesto + logging del fallo + volumen configurable por usuario, con un diálogo desde el header para probar cada tono.

### Pendiente de aclarar con Yusef

Dos cosas de la primera hoja que no entran en PR-9:

- **"Eliminar de la vista: Pre-Alerta y Pre-Factura."** La lectura más probable es que se refiere a los dos checkboxes `pre_alerta` y `pre_factura` del formulario de etiquetar — el digitador no debería estar marcándolos a mano. Confirmar antes de quitarlos.
- **"⊘ No imp a paquetes"** — no se logró descifrar la nota.

---

## Conversación 5: Tarifas, mínimos y etiqueta (2026-08-02)

> **Para revisión de Yusef.** Esta sección recoge lo hablado en las 3 reuniones grabadas del 2026-08-02, las 4 páginas de notas manuscritas y la etiqueta anotada. Si algo quedó mal entendido, corregirlo acá.

### El problema de fondo: el sistema no sabe cobrar

Los precios por libra sí están cargados (EXPRESS $8.00, CER $4.50, CEM $2.50, CKA $4.00, CKM $1.50), pero **el sistema no conoce ninguna de las reglas reales del negocio**:

- No existen los **cobros mínimos**. Un CKM de 2 libras hoy se factura por 2 libras, sin aplicar ningún mínimo.
- No existen los **precios escalonados** por rango de peso.
- No existen las **excepciones** por categoría de cliente o por promoción.
- Los precios están en **dólares** pero las facturas se muestran en **Lempiras sin convertir**, así que un CER de 10 libras aparece como "L. 45.00" cuando en realidad son $45.
- La categoría de precio del cliente solo distingue **aéreo o marítimo**, no el servicio. Por eso hoy un cliente "Regular" paga lo mismo en EXPRESS que en CER, cuando la lista dice $8.00 y $4.50.

Yusef lo resumió así:

> "**No tenés todavía la tabla de servicio. Creo que las puse a mano.** Hay que agregarlo al final de todo lo que estás haciendo."

### Las cuatro reglas de precio que hoy se manejan a mano

**1. Precio escalonado por peso**
> "Queremos hacer un precio escalonado: que de una a tres libras vale tanto, de tres a tal vale tanto. En la categoría hay que crearle eso."

**2. Precio especial por cliente y servicio** — por encima de la categoría
> "En el reempacado él es cliente amigo y se lo damos a $2, pero en el marítimo se lo voy a dar a $1.50. Solo le pongo que en el marítimo le voy a dar esa tarifa, y **esa es la excepción que arranca arriba de la tabla, pero solo en un servicio**."

Confirmado después por escrito:
> "Está el precio normal, precio por ser mayorista/familia etc., y está el **precio especial que está sobre todos los anteriores**."

**3. Categorías y promociones que anulan el mínimo**
> "Digamos Chain [Shein]: el mínimo de nosotros es 200 lempiras, pero en Chain solo es la libra o la media libra — inclusive le cobran media libra cuando es una cosita tan chiquitita. **Ahí es donde entran excepciones a las reglas normales del sistema.** En el instante que activamos esto, el sistema sabe que ya no existe la regla aquella."

Y sobre de qué depende el mínimo:
> "Ni sé cuál es el mínimo exacto, porque **depende del tipo de producto o promoción** — Shein, Temu, y otros como doTERRA o Farmasi."

**4. Cobro por media libra** en esos mismos casos, en vez de libra entera.

### Cómo se resuelve el precio de un paquete

Gana la regla **más específica** que aplique:

1. **Precio especial del cliente** para ese servicio
2. **Promoción del proveedor** (Shein, Temu, doTERRA, Farmasi…)
3. **Categoría de precio** del cliente
4. **Precio de lista** (público)

Dentro de la regla que gane, se usa el escalón de peso que corresponda. Y si hay una tarifa específica para la sucursal, esa manda sobre la general — porque:
> "En algunas sucursales manejan el mismo precio y en otras hay una pequeña diferencia (**costo extra de transporte**)."

### Las categorías de cliente

Yusef enumeró: **revendedores** (los precios más bajos), **mayoristas** (intermedio), **personal de CEC** (también de los más bajos), **clientes amigos**, **familia**, **Exchange / Chain** (sin mínimo, media libra) y **empresas de carga especial**.

Hoy el sistema solo tiene Regular, VIP y Mayorista. ✅ **Los precios llegaron el 2026-08-05** — ver "La tabla de precios recibida" más abajo.

### Los cobros mínimos

| Servicio | Documentado en abril | Lo dicho en el audio | Estado |
|---|---|---|---|
| CER | L.200 con ISV | coincide | ✅ |
| CKA | L.200 con ISV | coincide | ✅ |
| EXPRESS | $14.95 con ISV | "$10 más ISV" | ✅ **$10 sin ISV** — confirmado en la tabla del 2026-08-05 |
| CEM | 8 libras | "3 o 4 libras" | ⬜ la tabla trae mínimo en dinero (L.200 con ISV), no en libras |
| CKM | 20 libras | "3 o 4 libras" | ⬜ ídem — ver la contradicción de abajo |

**Reglas confirmadas por escrito:**

- Los L.200 son **con el ISV adentro**: *"L.173.91 más ISV (queda en L.200.00 ya con ISV)"*. El sistema guarda el neto y muestra ambos valores.
- El mínimo de EXPRESS, en cambio, es **sin ISV**: *"$10 **más** impuesto de venta"*. Los dos casos conviven en la misma tabla — es por eso que `minimo_monto` guarda siempre el neto y el CRUD pregunta por el monto con impuesto.
- El mínimo es **por concepto, no por factura**: *"El flete lleva su mínimo dependiendo el servicio, así como las recolectas."*
- **Todo tiene que ser editable**: *"TODOS ESTOS PRECIOS DEBEN PODER CAMBIAR"* — incluida la moneda del mínimo, porque *"puedo variar de valor o pasar a base dólares"*.

Las tres reglas quedaron fijadas como tests en `test/models/tarifa_reglas_yusef_test.rb`, con las citas textuales.

> ⚠️ **CKM cae en dos reglas que se contradicen** — y la contradicción está dentro del mismo audio:
>
> *"Los servicios **serie CK** son 200 lempiras ya con ISV"* → aplica a CKA **y CKM**
> *"El **marítimo** lo tenemos estipulado en cantidad de libras… mínimo 3 o 4 libras"* → aplica a CEM **y CKM**
>
> CKM es de la serie CK **y** es marítimo, así que entra en las dos. Falta saber cuál manda para CKM: el mínimo de L.200, el de libras, o los dos y gana el que resulte mayor. (El modelo soporta las tres opciones; es una decisión de negocio.)

### La tasa de cambio es fija

El dólar **no se jala automático**: lo fija un administrador en el sistema. (Hoy hay un proceso que lo actualiza solo todas las mañanas desde internet — se desactiva, porque le sobrescribiría la tasa que Yusef ponga.)

### Flujo operativo de Miami

Documentado por primera vez, del audio:

1. Llega el camión y entrega la carga
2. **Se separa por tipo de servicio** mientras se recibe
3. Pasa al área de mesas: se **etiqueta y digita**
4. Se coloca en **estantería**
5. Se **empaca** en las cajas de salida (tamaños predeterminados: **E**, **mini D**, **mini D doble**)
6. ⬜ **Falta el escaneo al empacar** — ver "Pendiente de diseño" abajo

### La etiqueta

Yusef mandó la etiqueta del sistema actual con cada campo anotado. **Es la primera vez que queda documentado qué lleva la etiqueta física** — el spec anterior (`docs/warehouse_receipt_fields.md`) ya no está en el repo.

| # | Campo | Ejemplo | Observación |
|---|---|---|---|
| 1 | Código de barras del número de recepción | — | 🆕 no existe hoy |
| 2 | Número de recepción | `RE0000577711-2-1/2` | |
| 3 | Tracking original | `TBA333187639911-2-1` | 🆕 falta agregar el secundario |
| 4 | Nombre del cliente | `YUSEF SAMARA` | 🆕 falta agregar el nombre del tercero |
| 5 | Fecha y hora de recepción | `30-jul.-2026 08:50 a.m.` | |
| 6 | Iniciales de quien registró | `Y.G.` | ya existe |
| 7 | Código del cliente | `C6` | va **completo** |
| 8 | Sucursal donde retira el cliente | `SAN PEDRO SU` | ⚠️ sale truncado y sin encabezado |
| 9 | Número y cantidad de paquetes | `1/2` | |
| 10 | Tipo de envío | `EXP` | |
| 11 | Departamento y ciudad del cliente | `Cortés · San Pedro Sula` | departamento abreviado + ciudad o pueblo |

**El problema del "San Pedro Soda":** en el documento que imprime el sistema hoy, la sucursal aparece bajo un encabezado en inglés (`Agent`) que nadie entiende, y el nombre sale cortado. Con Ceiba y la nueva sucursal de Tegucigalpa en camino, eso deja de ser un detalle.

**Hay cuatro etiquetas distintas**, una por operación:

| Operación | Tamaño | Marca | Dónde se pega |
|---|---|---|---|
| **ETIQUETAR** | **2.25 × 1.25 in** | Dymo | Una **por paquete** (si el tracking se divide en 5, van 5 etiquetas) |
| MANIFIESTO | 4 × 6 in | FreeX | Una por caja o paquete |
| PRE-FACTURA (SPS) | 4 × 6 in | FreeX | Por paquete; un paquete puede llevar varios tracking |
| MANIFIESTO NACIONAL | 4 × 6 in | FreeX | Por fuera; lleva varias pre-facturas, que llevan varios tracking |

⚠️ **Solo se va a rediseñar la de ETIQUETAR.**

✅ **Resuelto (2026-08-06).** Yusef cerró las dos cosas que faltaban:

> "No creo cambiar el tamaño de la etiqueta. **Allí es letra pequeña unas y otras grandes.**"

O sea que la respuesta no era recortar campos: **van los 11**, y lo que cambia es el cuerpo de letra. El tamaño de 2.25 × 1.25 in se queda.

La jerarquía quedó así:

| | Campos |
|---|---|
| **Grande** — se lee de lejos en la estantería | Número de recepción, tipo de envío, código y nombre del cliente, sucursal donde retira, n/N de paquetes |
| **Chico** — solo hace falta tenerlo a mano | Tracking principal y secundario, tercero, driver, ciudad del cliente, fecha y hora, iniciales |

> El presupuesto vertical es de 1.15 in de contenido y con los 11 campos queda
> al filo. `overflow:hidden` recorta **en silencio**, así que tercero y driver
> comparten renglón (el caso de Entrega Personal, que suele traer los dos) y el
> interlineado va apretado a mano. Cualquier campo que se agregue de acá en
> adelante hay que imprimirlo para verificar: ningún test atrapa un recorte de
> CSS.

Hoy el sistema no imprime una etiqueta: imprime un **Warehouse Receipt** en hoja carta con términos y condiciones, que es el documento equivocado para pegarle a una caja. Se van a separar: la etiqueta para la caja, el Warehouse Receipt para el expediente.

### Otros ajustes pedidos

**En Entrega Personal** — falta el cálculo del cobro:
> "Hay que agregarle para poder [ver] el valor a pagar. Copiar básicamente peso, medidas y cálculo. De acuerdo a la tarifa que tiene el cliente asignado."

El valor a pagar se muestra **en dólares y en lempiras**. El cliente puede pagar **en Miami o en Honduras** — las dos opciones ya existen en la pantalla.

**En Entrega Personal — proveedor y driver son dos cosas distintas.** Yusef corrigió el formulario:

> "Aquí tenés mal: aquí es proveedor y aquí es el driver."
> Jorge: "Viene Walmart y te manda el driver, ¿verdad?" — Yusef: "Sí, correcto."
> "Es donde tiene que ser editable, que es el driver."
> "Remitente o quien envía está bien, pero igual **otro driver** para poner el nombre del driver, en caso de tenerlo, **por el rótulo**."

- **Proveedor** = la empresa que mandó el paquete (Walmart, Amazon…). Es el catálogo `Proveedor`, recurrente.
- **Driver** = la persona que lo trajo físicamente. **Texto libre, no catálogo**, porque cambia en cada entrega.
- **Remitente** se queda como está — es un tercer dato, no se pisa con el driver.
- El driver **se imprime en la etiqueta**; para eso lo pidió.

Yusef además va a crear un proveedor llamado "Entrega local / personal" desde el CRUD. Hoy no hay ninguno de tipo `entrega_personal` cargado, así que la pantalla muestra el aviso de que falta configurarlos.

**En Etiquetar:**
- **Buscar el código ignorando los ceros**: hoy si el operario escribe `C002` no encuentra a `C2`. *"Cuando hago búsquedas por código, quitar los ceros."* El formato del código no cambia — `C6` está bien.
- **Búsqueda combinada de código y nombre**: poder escribir `"2 María"` y que aparezca. *"A veces llegan las etiquetas rotas, solo dicen 234 y después dice Pérez Hernández."*
- **F4 para agregar un tercero**, oculto por defecto: *"Que sea oculto, porque confunde si no. De clientes tercero recibimos 20% por mucho."*
- **En el modal de tracking repetido**, mostrar el **contenido y el tipo de servicio**: *"esas son las dos cosas que más te faltan ahí."*
- **Remitente** baja junto a Carrier y Proveedor.
- La **cantidad de cajas se queda en el modal** al imprimir. Yusef lo revisó y lo confirmó: *"Ya no me acordaba de eso, pero fíjate que al final está mejor. Me parece bien esto."*

### Pendiente de diseño (no se construye todavía)

**Escaneo al empacar y pre-etiqueta de caja.** Yusef pidió explícitamente dejarlo planificado:

> "No quiero que el sistema se complique, pero **quiero que lo planifiquemos aunque lo dejemos por fuera — que quede ya planificado y le dejes los accesos, los campos para amarrarlo**."

Lo que describió:
- Se crea una **pre-etiqueta de caja** con el tipo de servicio y el tamaño de caja, editable después por si la cortan.
- El operario escanea cada paquete con un escáner inalámbrico al meterlo a la caja.
- **Si el tipo de servicio no concuerda con el de la caja, el sistema pita.**
- Al crear el manifiesto se **jalan las cajas ya empacadas**, no paquetes sueltos.
- Con un botón de "omitir" para no trabar la operación.

El motivo real es de servicio al cliente:
> "Hoy no sabemos si una carga salió. Por eso le decimos al cliente 'entre lunes y viernes', y el cliente te dice: qué rango tan grande, no me estás dando una fecha."

### "Label en el celular" — resuelto (Jorge, 2026-08-02)

La nota de la página 2 no era sobre imprimir ni ver la etiqueta desde el teléfono. Es sobre la **etiqueta física rota**: cuando el paquete llega con la etiqueta dañada, el operario solo alcanza a leer pedazos y tiene que dar con el cliente a partir de esos fragmentos.

> "A veces llegan las etiquetas rotas, solo dicen **234** y después dice **Pérez Hernández**, entonces uno tiene que andar ahí unificando."

La búsqueda combinada de código y nombre (PR-10.c) va en esa dirección, pero **no alcanza**: hoy exige que *todas* las palabras del término matcheen. Con una etiqueta rota eso es justo lo que falla — basta que un fragmento esté mal leído o pertenezca a otro campo para que no devuelva nada. Ver Fase 11, PR-10.f.

### Lo que falta que Yusef confirme

1. ✅ ~~La tabla de precios completa~~ — llegó el 2026-08-05, ver abajo.
2. El **mínimo por defecto de CEM y CKM** en libras.
3. ✅ ~~El mínimo de EXPRESS~~ — **$10 sin ISV**.
4. ✅ ~~Cuáles de los 11 campos de la etiqueta son imprescindibles~~ — van los 11, con jerarquía de cuerpos de letra, y el tamaño no cambia.

---

## La tabla de precios recibida (2026-08-05)

Yusef mandó `precios por categoria 2026.xlsx`. Es lo que bloqueaba cargar los
precios de verdad: el motor de tarifas está construido desde PR-10.a pero venía
corriendo con el backfill de la migración, que solo replicaba el comportamiento
viejo (un precio plano por servicio, sin mínimos ni escalones).

El archivo trae tres hojas: `Hoja1` (borrador), `ACTUAL` (lo que cobran hoy) y
**`PROPUESTA`** (lo que quieren cobrar). Se sembró la PROPUESTA — PR-10.g.

### El archivo confirmó el diseño

Yusef llegó por su cuenta a la misma estructura que el modelo:

| En su archivo | En el sistema |
|---|---|
| `MONTO EN LPS CON ISV` → 200 | `minimo_monto` guarda el neto **173.91** |
| `MONTO EN $ MAS ISV` | mínimo neto, el ISV se aplica al totalizar |
| Columnas NORMAL / MINIMO por categoría | `precio_libra` / `minimo_monto` |
| `TARIFARIO ESCALONADO` con rangos de libras | `desde_libras` / `hasta_libras` |
| `SIN COBRO MINIMO` como categoría | `aplica_minimo: false` |
| `13.5 A 100 LIBRAS EN SPS` vs `EN TGU` | `sucursal_id` |

En la hoja ACTUAL el mínimo figuraba como **6.45 USD** y en la PROPUESTA pasó a
**173.91** — o sea que adoptó la convención del neto sin ISV por su cuenta.

### Precio por libra y mínimo, por categoría

Montos en USD salvo donde diga lo contrario.

| Servicio | Amigos | doTERRA / Farmasi | Personal CEC | **Lista (público)** | Shein | Sin Cobro Mínimo |
|---|---|---|---|---|---|---|
| CER | 4.20 / $5 | 3.50 / $5 | 3.50 / — | **4.50 / L.173.91** | 3.50 / — | 4.50 / sin mínimo |
| CKA | 3.80 / $5 | 3.50 / $5 | 3.00 / $3 | **4.00 / L.173.91** | 3.50 / — | 4.00 / sin mínimo |
| EXPRESS | 7.00 / $10 | 7.00 / $10 | 6.50 / — | **7.50 / $10** | 7.00 / — | 7.50 / sin mínimo |
| CEM | 2.20 / — | 1.70 / — | 1.80 / $1.80 | **2.50 / L.173.91** | 1.75 / — | 2.50 / sin mínimo |
| CKM | 1.70 / — | 1.70 / — | 1.40 / $1.40 | **1.90 / L.173.91** | 1.75 / — | 1.90 / sin mínimo |

**Un MINIMO en 0 en la hoja significa "sin definir", no "mínimo de cero"** — se
carga como sin mínimo.

`MAYORISTAS` viene casi entero en cero: el único servicio con precio es **CKM a
$1.50**. `FAMILIA` y `REVENDEDORES` vienen todos en cero, así que las categorías
se crearon pero sin tarifas — sus clientes caen al precio de lista.

### Tegucigalpa es sobrecosto por sucursal, no categoría

`Precio Tegus` y `SHEIN TGUS` no son categorías de cliente: son la misma tarifa
con el costo extra de transporte a Tegucigalpa. Van como fila con `sucursal`, y
es el sistema el que la aplica cuando el paquete va para allá — el cajero no
elige nada. Si fueran categorías, al abrir La Ceiba habría que duplicar cada una
otra vez.

Solo tres precios difieren en Tegucigalpa:

| | SPS y el resto | Tegucigalpa |
|---|---|---|
| CKM lista (13.5–100 lb) | $1.90 | **$2.00** |
| CEM Shein | $1.75 | **$1.90** |
| CKM Shein | $1.75 | **$1.90** |

### Los tarifarios escalonados

Solo el **precio de lista** tiene escalones; las categorías son precio plano.

| CER | | CEM | | CKM | |
|---|---|---|---|---|---|
| 0–50 lb | $4.50 | 0–3 lb | $4.50 | 0–3 lb | $4.00 |
| 50.5–100 | $4.00 | 3.5–100 | $2.50 | 3.5–13 | $2.50 |
| 100.5–150 | $3.75 | 100.5–200 | $2.20 | 13.5–100 | $1.90 · **TGU $2.00** |
| 150.5+ | $3.50 | 200.5+ | $2.00 | 100.5–200 | $1.75 |
| | | | | 200.5+ | $1.65 |

CKA y EXPRESS no tienen escalonado: precio plano.

Dos decisiones de lectura sobre la hoja:

- El primer tramo de cada tarifario (`DE 0 A 1 LBS → L.200 CON ISV`) no es un
  precio por libra sino **el mínimo**, y el mínimo ya va en toda la fila. Queda
  absorbido en el tramo siguiente: a 1 lb de CER el cálculo da $4.50 ≈ L.112,
  por debajo del mínimo, y se cobra L.173.91 igual (L.200.00 con ISV).
- Los cortes de CEM y CKM dicen `101` y `201` donde CER dice `100.5` y `150.5`.
  Se tomó el patrón de CER (medias libras) para los tres: si no, un paquete de
  100.5 lb caería en un hueco sin tarifa.

### "TARIFA EDITABLE CON AUTORIZACION DE SUPERVISOR O JEFE" es una función del sistema

La nota se repite en casi todas las filas de los tarifarios escalonados. Al
principio se leyó como una descripción de su proceso interno. **No lo es** —
Yusef lo aclaró (2026-08-05):

> "Ahí, como es el área de pre-facturación, no hemos entrado ahí, en donde entra
> ya ciertas cosas que los supervisores o jefes son los que [autorizan el]
> cambio. Por eso queremos que el área de los precios estén establecidos, listo.
> **No hay nada más, no se puede hacer más si está todo preestablecido.** Ahora,
> si lo quieren modificar, ellos tienen que pedir autorización — ahí es donde
> entra un jefe, un supervisor, y ahí es donde llega y **pone un código especial
> de él**."

O sea, el circuito completo es:

1. Los precios se cargan una vez en `/servicios` (solo admin). Esa parte ya está.
2. **En la pre-factura el cajero no puede tocar el precio.** Sale preestablecido
   de la tabla de tarifas y punto.
3. Si en el mostrador hay que cambiarlo, el cajero **pide autorización**.
4. El supervisor o jefe llega, **teclea su código** en la pantalla, y eso
   destraba la edición de esa línea.
5. Queda registrado quién autorizó qué.

Lo importante es el punto 2: el precio bloqueado por defecto es el requisito, no
un detalle de la pantalla. La autorización es la excepción.

> 🔴 **Hoy el sistema hace lo contrario.** `PreFacturasController#pre_factura_params`
> permite `precio_libra` y `subtotal` en las líneas, así que cualquiera con acceso
> a pre-facturas edita el monto sin dejar rastro de por qué. Ver Fase 13.

**El detalle, respondido el mismo día:**

| | |
|---|---|
| **El código** | Un **PIN de 4 dígitos**, aparte de la contraseña del supervisor |
| **Qué destraba** | **Todo**: precio, descuento, quitar líneas y cambiar el peso a cobrar |
| **Alcance** | **Por línea** — no se autoriza la pre-factura completa |
| **Quién autoriza** | `admin`, `supervisor_prefactura`, `supervisor_caja` y **`supervisor_sac`** |

**Falta un rol.** `sac` ya existe (el agente de servicio al cliente); lo que no
está es **su supervisor**, que Yusef cuenta también como jefe. Hay que agregar
`supervisor_sac` y darle sus permisos.

Dos cosas que salen de esas respuestas y hay que resolver al construirlo:

- **El descuento no existe como dato.** Hoy un descuento se hace bajándole el
  precio a la línea, así que la factura sale sin decir que hubo descuento, ni de
  cuánto, ni quién lo dio. Si el PIN va a autorizar descuentos, el descuento
  tiene que ser una columna.
- **Un PIN de 4 dígitos son 10 000 combinaciones.** Es el único punto del
  sistema donde cuatro números habilitan cambiar plata, así que va con `bcrypt`
  y con límite de intentos, no guardado en claro.

El detalle técnico está en `docs/06` — Fase 13.

### Lo que sigue abierto de la tabla

1. **El mínimo en libras de CEM y CKM.** El archivo trae mínimos en dinero pero
   no el de libras que Yusef mencionó ("3 o 4 libras"). En la práctica el
   escalonado ya lo cubre — el tramo chico de CEM cobra $4.50/lb, así que un
   paquete de 2 lb paga $9 — pero conviene confirmarlo.
2. **La contradicción de CKM sigue en pie.** El archivo le pone el mínimo de
   L.173.91, lo que sugiere que manda el monto sobre las libras. Confirmar.
3. **`Regular` y `VIP` no aparecen en el archivo**, y tienen 8 clientes
   asignados. Hay que decidir si se migran a alguna de las categorías nuevas o
   se retiran. Mientras tanto se quedan con los precios viejos.
4. **`MAYORISTAS` solo tiene CKM definido.** Sus otros cuatro servicios siguen
   con los valores del backfill de PR-10.a.
5. **Las categorías no bajan de escalón.** Un cliente `Clientes Amigos` con 200
   lb de CER paga $4.20/lb ($840) mientras el público paga $3.50/lb ($700) —
   porque su columna es un precio plano y el escalonado está declarado solo para
   el precio de lista. Es literal a la hoja, pero hay que preguntarle si es lo
   que quiere.
6. **Los 16 cargos que no son flete** — parcialmente resuelto, ver abajo.

### Los cargos que no son flete (PR-10.i)

De las 16 filas que no son tipos de envío, **se cargaron cinco**: los que el
propio texto de la hoja define sin dejar dudas.

| Cargo | Precio | De dónde sale la certeza |
|---|---|---|
| Entrega nacional | **L.86.96** | El título dice `L100` y 86.96 + ISV = L.100.00 exactos |
| Compra online | **$1.00** | Su nota: *"ponerlo $1 más ISV"* |
| Manejo y gastos de destino | **L.1.00** | Su nota: *"ponerlo lps1 más ISV"* |
| Flete internacional UPS | **$1.00** | El título dice `FLETE INTERNACIONAL UPS $1` |
| Retornado en Miami | **$5.00** | Su nota: *"todo en $"* |

Ninguno lleva el ISV adentro: la fila 30 de la hoja dice
`**PRECIOS NO INCLUYEN IMPUESTOS`, y eso sí aplica a todo.

#### ⬜ Los otros diez esperan a que Yusef confirme la moneda

**La hoja tiene una leyenda de colores que nunca se aplicó.** Las filas 31 y 32
declaran `**PRECIOS EN $` y `**PRECIOS EN LEMPIRAS` con su color, pero al leer
los rellenos del XLSX **todas las celdas de precio tienen relleno nulo**. O sea
que el número solo no dice en qué moneda está.

Cargarlos adivinando sería peor que no cargarlos — son montos que se le cobran
al cliente.

| Cargo | Por qué no se cargó |
|---|---|
| **Cambio de servicio** | El título dice `L100`, el valor es `5` y la nota *"pasarlo a dólares"*. Y **ya existe cargado a $15**, que es 3× lo que dice su hoja. Es el que se **auto-genera** en nota de débito al facturar, así que tocarlo a ciegas cambia lo que se cobra solo |
| Retenido Miami | Valor `5` con *"pasarlo a dólares"*: no se sabe si el 5 ya es dólares o falta convertirlo |
| Servicio de entrada y salida | Valor `10` / mínimo `5`, misma nota, misma duda |
| Recolecta Miami | Choca con `TarifaRecolecta`, que Yusef mismo pidió **por zona** en vez de los $35 fijos |
| Ajuste · Entrega local · Consolidando en Miami | Valor `1` sin moneda |
| Flete México | Valor `5` / mínimo `6` sin moneda |
| Flete | Es el flete del paquete, que vive en `Tarifa` — no es un servicio extra |
| Producto ejemplo (×2) | Datos de prueba, ya confirmado |

Se aplican con `bin/rails tarifas:sembrar_cargos_2026`, que además **imprime los
diez pendientes con su motivo** para que no se pierdan de vista.

---

## Conversación 6 (2026-08-08): Prueba en vivo de /etiquetar

Yusef sentado frente al sistema nuevo, probándolo campo por campo con Jorge al
lado. Es la primera vez que **opera** `/etiquetar` en vez de opinar sobre
capturas, y por eso salieron cosas que ninguna revisión de diseño iba a agarrar.

Se entrega en tres partes:

| Parte | Estado |
|---|---|
| **Audio 1** — prueba de `/etiquetar` y `/paquetes` | ✅ documentada abajo (`A1-nn`) |
| **Audio 2** — monedas, cargos extra y escalonado | ✅ documentada abajo (`A2-nn`) |
| **Imágenes** — 3 páginas de notas a mano de Jorge | ✅ cruzadas abajo (`N-nn`) |

Los items van con ID `A1-nn` para poder cruzarlos cuando lleguen las otras dos
partes. Cada uno lleva su estado:

- **BUG** — reportado por Yusef y confirmado leyendo el código
- **YA ESTÁ** — Yusef lo pidió y ya existe (o existe a medias)
- **NUEVO** — no está y hay que hacerlo
- **PREGUNTA** — no se puede implementar sin que Yusef defina algo
- **FUTURO** — lo quiere, pero no ahora

---

### El tema de fondo: el teclado es la herramienta

Yusef lo dijo dos veces y explica la mitad de la lista:

> "Nosotros solo teclado porque usamos las manos para trabajar."

Y sobre el Enter:

> "El enter es como el siguiente campo."

La pistola de código de barras **dispara Enter** al terminar de leer. Eso no es
configurable en la práctica: hay varias pistolas, unas con cable y otras sin, y
todas vienen así. O sea que en `/etiquetar` el Enter no es "aceptar el
formulario" — es "terminé este campo, seguí".

---

### A1-01 · Enter guardaba el paquete en vez de pasar al siguiente campo — ✅ **ARREGLADO** (PR-C6.3)

El más grave de todos, y del que cuelgan otros cuatro.

> "El error está en el enter, el enter es el que hace todo el carnal."

`etiquetar/index.html.erb:213` es un `form_with` normal y
`etiquetar_controller.js:41-63` solo intercepta F2/F3/F4/F8/F9. **No hay ningún
handler de Enter**, así que gana el comportamiento por defecto del navegador:
Enter en un input de texto envía el formulario.

Consecuencias que Yusef vio en vivo:

1. El paquete **se graba incompleto** apenas escanea el tracking.
2. Al grabarse sin sucursal, `generate_numero_recepcion`
   (`paquete.rb:555-556`) sale temprano por el `return if sucursal.nil?` y el
   `numero_recepcion` queda vacío → ver A1-02.
3. Se le asignó a un usuario que él no eligió ("se lo asignó a María López
   cuando yo no se lo había puesto a nadie").
4. Después de ese Enter, **F2 ya no limpia** → A1-03.

**Arreglo (PR-C6.3).** `formKeydown` en el form: Enter avanza al siguiente
campo visible y habilitado, y en los dropdowns deja seleccionar el ítem activo.
Nunca envía.

Tres cosas del handler que no son obvias:

- **Respeta `e.defaultPrevented`**, para no pisar el Enter del dropdown de
  cliente ni el del modal de cajas, que ya lo resuelven ellos.
- **Salta los `textarea`** — en descripción y notas Enter tiene que ser salto de
  línea.
- **Recalcula los campos en cada Enter**, porque F3 y F4 muestran y esconden el
  tracking secundario y el tercero; una lista cacheada quedaría vieja.

Cubierto por `test/system/etiquetar_teclado_test.rb`, que es lo único que puede
verlo: en un test de integración no hay navegador que decida qué hace un Enter.

El test fiel usa un tracking **con pre-alerta**, y ahí está la gracia: al salir
del campo, `checkTracking` auto-rellena el cliente, y con tracking + cliente el
paquete ya pasa las validaciones. Sin pre-alerta el test no probaría nada,
porque el guardado fallaría igual.

> "Grabar con tab o enter — o sea, grabar no, **seleccionar**."

Y explícitamente: en `/etiquetar` **no hay autoguardado**. Jorge preguntó porque
en pre-alerta sí lo hay, y Yusef marcó la diferencia:

> "Sí, pero no en editar. Hay campos obligatorios, no lo puede grabar sin los campos."

---

### A1-02 · En /paquetes el tracking salía dos veces seguidas — ✅ **ARREGLADO**

Minuto **41:02**, viendo el listado:

> "Esto está malo... porque te está poniendo el tracking y el número de recepción."
> "Es que el número de recepción es como el número de registro."

Y en **38:53**: *"el primer error es el número de recepción"*.

**No era un problema de datos.** En la base hay **cero** paquetes con
`numero_recepcion = tracking`. Se verificó:

| | |
|---|---|
| Paquetes totales | 54 |
| Con `numero_recepcion = tracking` grabado | **0** |
| Sin `numero_recepcion` | 45 |
| Sin sucursal | 45 |

Era la **vista**. Las columnas "N° recepción" y "Tracking" son vecinas, y la
primera usaba `paquete_display_id`, que cae al tracking cuando no hay
recepción:

```ruby
# paquetes_helper.rb:43
paquete.numero_recepcion.presence || paquete.tracking
```

Y no hay recepción en 45 de 54 paquetes porque `generate_numero_recepcion`
(`paquete.rb:556`) sale temprano con `return if sucursal.nil?`. Resultado: el
mismo texto en dos celdas pegadas.

**El PDF del listado tenía exactamente el mismo bug** (`listado_pdf.rb:46`):
mismas dos columnas vecinas, mismo fallback. Los dos Excel
(`paquetes_controller.rb:471`, `export.xlsx.axlsx:18`) sí ponían "—".

**Y hay un segundo camino al mismo síntoma** que la base local no puede
reproducir: filas viejas con la recepción **guardada** igual al tracking. Jorge
lo dijo en el audio:

> "Estos están hechos porque yo los metí en la base de datos en este formato."

En local eso da 0 filas, pero **la reunión fue sobre staging**, así que el
arreglo cubre los dos casos.

**Arreglo:** `Paquete#numero_recepcion_visible` devuelve `nil` cuando no hay una
recepción de verdad — en blanco **o** igual al tracking — y las cuatro
superficies del listado (pantalla, PDF y los dos Excel) ponen guión.

Se puede comparar contra el tracking sin miedo a falsos positivos porque una
recepción real es siempre `<PREFIX><AÑO 7><CORRELATIVO 6>` (`RM0002026000010`),
que no se parece a ningún tracking de courier.

`paquete_display_id` **no se tocó** — como identificador de un título el
fallback sirve; el problema era usarlo en una columna que se llama
"N° recepción" con el tracking pegado al lado.

Cubierto por `test/controllers/paquete_numero_recepcion_columna_test.rb`
(5 tests, incluido el del PDF; verificados reintroduciendo cada guard a
propósito).

El formato anual del número **está bien** y no se tocó
(`numero_recepcion_counter.rb`): `<PREFIX><AÑO><CONTADOR-6>`, contador atómico
con `SELECT FOR UPDATE`, reinicia cada enero. Ej. `RM0002026000010`. Es el
número del Warehouse Receipt. Lo único pendiente ahí es el **mes** que pidió
Yusef → ver preguntas.

✅ **La causa raíz se cerró en PR-C6.5.** Y no era el Enter como decía este
doc: **`/etiquetar` nunca asignaba sucursal** — cero menciones en el controller
y cero en la vista. Como `generate_numero_recepcion` sale temprano sin
sucursal, la correlación en la base era perfecta: 45 sin sucursal, los mismos
45 sin número.

Debajo había un choque de significados. `paquetes.sucursal_id` era a la vez
"dónde retira el cliente" (etiqueta, listado, y la **búsqueda de tarifa** en
`pre_factura.rb:201`) y "de dónde sale el prefijo del número" (`RMI` = Recibido
Miami). Un paquete se recibe en Miami y se retira en Zeron SPS; una columna no
puede ser las dos, y por eso `/etiquetar` no podía asignar ninguna.

Se separó en `paquetes.sucursal_recepcion_id`. `sucursal_id` no se tocó.

⚠️ **Y queda un caso peor con el mismo fallback:** `_etiqueta.html.erb:29`
codifica `numero_recepcion.presence || tracking` **en el código de barras**. Si
el paquete no tiene recepción, la etiqueta sale con un barcode del tracking —
justo lo que Yusef prohibió (*"el código de barra que está aquí es el warehouse,
no es el tracking"*, minuto 42:19). Se atiende junto con A1-04, porque la
decisión no es obvia: sin recepción, o no se imprime barcode, o no se debería
poder etiquetar el paquete.

---

### A1-03 · Después de un Enter, F2 no limpiaba — ✅ **ARREGLADO** (PR-C6.3)

> "Le doy F2 y no limpia. Le doy enter y presiono F2, no lo borra."

F2 tiene que limpiar **todo**, siempre:

> "Todo, todo. Porque se equivocó y lo mejor es F2 y volvemos a empezar."

**El diagnóstico de este doc estaba mal.** Decía "problema de foco", pero el
listener de F2 es a nivel `document` (`etiquetar_controller.js:26`), así que el
foco no puede ser la causa.

Lo real: `clearForm` usaba `formTarget.reset()`, y **`reset()` no vacía un
formulario** — lo devuelve a los valores *renderizados*. Cuando el submit del
Enter fallaba y el servidor re-renderizaba con 422, esos valores eran los que
Yusef acababa de escribir. F2 "limpiaba" de vuelta a lo mismo.

**Arreglo (PR-C6.3):** `_limpiarCampos` vacía campo por campo. Los `hidden`
quedan afuera a propósito — ahí viven el token CSRF y el `_method` de Rails; los
dos que sí hay que limpiar (`cliente_id` y `cantidad_paquetes`) ya los maneja
`clearForm` explícitamente.

---

### A1-04 · El código de barras no distingue caja 1 de caja 2 — **BUG confirmado**

Este es el centro de la reunión y el que más plata mueve, porque de acá cuelga
el inventario.

`_etiqueta.html.erb:29` codifica el `numero_recepcion` pelado. Pero
`crear_split!` (`paquete.rb:367-395`) le asigna a las N cajas **el mismo**
`numero_recepcion` — el número madre — y las diferencia solo por `numero_caja`
(el unique index es compuesto: `(numero_recepcion, numero_caja)`).

O sea que las dos cajas de un tracking dividido **llevan el mismo código de
barras impreso**. Escanear no dice cuál es cuál:

> "Si yo escaneo esto no sé si es el paquete uno o el paquete dos."

El `n/N` sí sale impreso como texto (`etiqueta_fraccion`), pero no va adentro
del código escaneable, que es lo único que se lee en San Pedro.

Por qué importa: al recibir en San Pedro se escanea para **rebajar del
inventario**, y ahí hay que saber cuál de las N cajas llegó y cuál falta.

> "Esa etiqueta selecciona del inventario... el paquete que sí vino, y que falta
> el otro. De esa manera él rebaja."

Lo que pidió: que el código lleve el sufijo de caja — `7-1`, `7-2`.

> "Donde vos se lo vas a tener que poner es aquí: acordate que aquí va el 6 —
> bueno, aquí sería 7-1, 7-2."

Y la contraparte, igual de importante:

### A1-05 · El sufijo `-1`, `-2` va en la recepción, **nunca** en el tracking — **regla**

Es el error que arrastraba el sistema viejo y que confundió a todo el mundo:

> "El tracking él le agregaba un 2, y al warehouse él le agregaba un 2 y el 1."

> "Este -1 y -2 al tracking no es necesario ponérselo."

El tracking es del courier y no se toca. La única excepción es el sufijo
`A`/`B`/`C` para trackings **duplicados de verdad**, que es otra cosa
(`next_duplicate_suffix`).

---

### A1-06 · Cambiar la cantidad de paquetes no elimina ni crea los sobrantes — **BUG**

Yusef lo reprodujo dos veces en vivo:

- Un paquete con 3 cajas → lo editó a 2 → **quedaron las 3**.
- Después lo subió a 5 → quedaron los registros viejos mezclados con los
  nuevos: "aquí dice dos y aquí dice que son cinco".

`crear_split!` solo sabe **crear** N cajas. No hay una operación de *ajustar* de
N a M sobre un split que ya existe.

La regla que acordaron es simple: la cantidad nueva manda.

> **Jorge:** "Si tienes cinco y lo quieres cambiar a dos, solo deberían quedar los dos."
> **Yusef:** "Eliminar lo otro. Ajá."

Ojo al implementarlo: eliminar cajas que ya estén facturadas o entregadas no
puede ser silencioso.

---

### A1-07 · Miami actualiza desde /etiquetar, no desde /paquetes — **NUEVO**

Hoy, cuando escanean un tracking que ya existe y eligen "actualización", el
sistema los manda a `/paquetes/:id/edit`. Yusef no quiere eso:

> "Me mandaste a editar y yo no quiero editar mi paquete."

Lo que quiere: que el formulario de `/etiquetar` **se recargue con los datos que
ya tiene** el paquete, y ahí mismo lo corrijan y le den F9.

> "Que te cargue aquí la lista. Esto te lo vuelve a llenar tal cual como quedó,
> y actualizan todo lo que quieran actualizar, porque eso es lo que ellos ocupan."

La línea divisoria la definió él mismo, y es limpia:

| Qué cambia | Dónde |
|---|---|
| Datos que Miami **captura** — tracking secundario, tercero, courier, proveedor, medidas, peso, cantidad de cajas, tipo de servicio | `/etiquetar` |
| **Estado** del paquete — "lo escanearon que se iba y al final ya no se va" | `/paquetes` |

> "Si ellos entran a actualizar acá es porque van a actualizar datos del paquete,
> de lo que ellos ingresan."

Lo confirmó con Julián (Miami) por videollamada durante la reunión: sí, siempre
mejor en la misma hoja donde llenan.

Motivo de fondo: hoy actualizar 2 cajas cuesta ir a editar → guardar → volver →
re-imprimir → seleccionar. Yusef contó los pasos en voz alta y ahí se le acabó
la paciencia.

---

### A1-08 · Marcar "cambio de servicio" no pregunta a cuál — **BUG**

> "En etiquetar, al marcar cambio de servicio no está, no pregunta qué tipo de
> servicio."

Y cuando lo forzó por otro camino y guardó, **el tipo de envío no cambió**: se
quedó en CER. O sea que además de no preguntar, no aplica.

Jorge propuso un modal. Yusef no se casa con la forma, sí con la velocidad:

> "No sé, lo que funcione bien: solo darle click, yo doy click y click y ya va.
> Lo que vos creas que te funcione bien, que no cargue y que sea rápido."

---

### A1-09 · Alerta cuando el paquete no es del tipo de envío de la sesión — **NUEVO**

La sesión por tipo de envío **ya existe** (`etiquetar_controller.rb:3-4,
16, 28, 144-151`: `iniciar_sesion`, `finalizar_sesion`,
`require_tipo_envio_sesion`). Lo que falta es qué pasa cuando el paquete
escaneado no corresponde.

Yusef llamó a Julián (Miami) por video en plena reunión para decidirlo, y
quedó así:

Al escanear un paquete cuya pre-alerta tiene un tipo de envío distinto al de la
sesión → **sonido feo + modal** con dos opciones:

| Opción | Qué hace |
|---|---|
| **Cambiar de sesión** | Manda a finalizar sesión y volver a escoger tipo de envío |
| **Seguir en la misma sesión** | Limpia el formulario. El paquete **no se ingresa** |

La clave: en ningún caso se puede grabar bajo el tipo equivocado.

> "No te va a permitir grabarlo. No vas a poder hacerlo... el chavo no hizo nada,
> no pudo hacer nada."

Julián lo confirmó: mejor que lo obligue a cerrar la sesión.

> **Yusef:** "Si es CKM ya sabemos que se lo va a llevar tu papá. Como tienen el
> relajo en la mesa, los va a obligar a hacer los que son correctos."

---

### A1-10 · Sonidos — **YA ESTÁ a medias**

Existe el `audio_controller` cableado a tres eventos
(`etiquetar/index.html.erb:91`): `success`, `clienteNotas`, `speakPreAlerta`.
Yusef aprobó el que ya suena:

> "Ese pin está bien. Se oye amigable, no se oye así como que lo querés apagar."

El mapa completo que pidió:

| Cuándo | Sonido | Estado |
|---|---|---|
| Terminó de escanear y ya revisó pre-alertas — "podés seguir" | pin agradable | ✅ existe |
| Seleccionó el código de cliente | pin | ✅ existe |
| El paquete **tiene pre-alerta** | voz grabada | ⏳ falta la grabación |
| El tracking **ya existía / ya fue usado** | pito distinto | ❌ falta |
| **Error** — tipo de envío distinto al de la sesión | sonido feo | ❌ falta |
| **Antes** de que salga cualquier modal | pin | ❌ falta |

Son **dos** pitos distintos, no uno. Yusef lo dijo así:

> "Pita para dos razones... pita, te decía, pre-alerta, para que te fijaras que
> tiene pre-alerta." · "El otro pito es porque te tira que **ya existía**."

Y las notas de Jorge de esa misma reunión lo listan igual: *"pita — 1) pre-alerta
2) que ya existía"*.

Sobre el pin de confirmación, la razón no es cosmética:

> "Ahorita el sistema es bolazón, pero más adelante pueda que tenga un pequeño
> lag de milisegundos... Ocupamos la confirmación para que ellos puedan estar
> seguros de que pueden seguir."

La voz de pre-alerta es la de su señora, grabada en 2022-2023 para el sistema
viejo. Va a mandar grabaciones nuevas. Del sonido de error, Jorge le va a pasar
una lista para que elija.

---

### A1-11 · La ventana de impresión queda abierta — ✅ **ARREGLADO** (PR-C6.4)

F9 abre la etiqueta en pestaña nueva y ahí se quedaba. En un lote de 100
paquetes se juntaban 100 pestañas.

> **Yusef:** "Esto que ves acá debería de cerrarse."
> **Jorge:** "Cerrar y te tiro una limpia."

**Arreglo:** el layout de la etiqueta escucha `afterprint` y cierra. Cierra
tanto si imprimió como si canceló — lo que Yusef quiere es volver a escanear,
no decidir. Lleva un fallback por `matchMedia("print")` para el Safari viejo,
que no dispara `afterprint`.

El `clearForm` post-guardado ya existía, así que con esto queda el ciclo
completo que pidió: **F9 → imprime → se cierra → `/etiquetar` limpio**.

⚠️ **Lo que el test cubre y lo que no.** Chrome headless dispara `beforeprint`
pero **nunca `afterprint`** — no hay diálogo que cerrar; se verificó con una
prueba directa. Así que el ciclo real no se puede observar en CI. Lo que sí se
prueba es todo lo que es código nuestro: que el listener quede registrado y que
al llegar el evento la ventana se cierre. **Queda para verificación manual en
`:3090`**: imprimir de verdad y ver la pestaña desaparecer.

---

### A1-12 · Los atajos también arriba, no solo abajo — **NUEVO**

> "Estos botones los dejaste abajo y a veces se ocupan acá arriba. En ambos lados."

---

### A1-13 · Guardar es F10, como en el resto del sistema — ✅ **ARREGLADO** (PR-C6.3)

Yusef presionó **F10** para guardar sin pensarlo. Y tiene razón por costumbre:
F10 es guardar en pre-facturas, ventas, egresos, ingresos, financiamientos y
re-empaques. `/etiquetar` es el único que usa F8
(`etiquetar_controller.js:56`, `index.html.erb:435,445`), donde F8 en el resto
del sistema es *exportar a Excel*.

**Arreglo (PR-C6.3):** F10 guarda, y **F8 queda de alias** mientras Miami se
acostumbra — allá ya lo tienen en el dedo. Los `<kbd>` de la pantalla muestran
F10.

Queda la parte que no es código: **avisarle al equipo de Miami**.

---

### A1-14 · Buscar cliente por los últimos dígitos del código — **PREGUNTA**

> "El rollo de los códigos de cliente actuales es que tienen el `C00002867`.
> Actualmente el sistema lee de derecha a izquierda."

En el sistema viejo escriben solo `2867`, o hasta un solo dígito, y cae. Es
búsqueda por **sufijo**, no por prefijo.

> "Eso es algo que ya trabajan así, y si se los cambio... solo le ponían el dos."

Contexto: los códigos viejos son de 4 dígitos y los nuevos de 5. **Los viejos no
se migran** — se quedan como están.

**PREGUNTA:** con 5 dígitos y miles de clientes, teclear `6` va a traer cientos
de coincidencias. ¿Sufijo puro, o sufijo priorizado con match exacto primero?

---

### A1-15 · Orden de campos y navegación — **NUEVO**

Lo revisaron campo por campo:

| Cambio | Detalle |
|---|---|
| **Notas internas** sube | Arriba del cuadro de carrier/proveedor/remitente |
| **Carrier, proveedor y remitente** bajan | Al cuadro de abajo — "es parte de lo que van a llenar" |
| **Pre-alerta y pre-factura** se van de `/etiquetar` | "Eso no tiene nada que ver con ellos" — Jorge confirmó que quedaron del inicio |
| Tab desde **tercero** → descripción | Y si no activó tercero, de cliente → descripción directo |
| **F4** activa el tercero | ✅ ya está (`etiquetar_controller.js:50-55`) |

---

### A1-16 · El cliente tercero no se guarda en ninguna base de datos — **regla, YA ESTÁ verificar**

Yusef fue enfático porque es un tema de integridad de datos:

> "Solo se guarda en esa guía... Queda guardado en ese warehouse receipt, pero
> no queda grabado en ninguna base de datos de clientes."

Dos razones:

1. **Autoridad**: quien digita en Miami no decide quién es cliente.
   > "El que está digitando ahí no tiene ni voz ni voto para guardar."
2. **Errores**: "ellos se pueden equivocar y pueden hacer este relajo."

La excepción son los **revendedores**. Un cliente como Carlos Reyes tiene su
propia cartera de terceros, y ahí sí sale el dropdown con los suyos:

> "Él en su lista tiene su cartera de terceros... ahí sí me van a salir los de él."

O sea: texto libre por defecto; dropdown solo si el cliente titular es
revendedor y tiene terceros registrados.

⚠️ **Cruzar con PR-10.c**: hoy existe `tercero_search_controller.js` y el paquete
tiene `belongs_to :tercero`. Hay que verificar que el texto libre **no** esté
creando registros de cliente.

---

### A1-17 · Peso y medidas por caja, no una sola línea — **NUEVO**

> "Sinceramente sí se ocuparía hacerle esa mejora: ponerle cantidad dos y aquí
> te pregunta dos veces."

Si son 2 cajas, el formulario tiene que pedir peso y medidas **de cada una**. Hoy
solo pide una línea.

Dos formas, y dejó elegir:

- N líneas de una vez, según la cantidad
- Un botón "agregar" que va sumando de a uno y limpia entre cada uno

> "Como le importa que son dos, te da esa opción para dos. Al menos vos lo
> cambias a tres."

---

### A1-18 · Motivos de retención editables — **NUEVO + falta lista**

Hoy los motivos están fijos (paquete dañado, mercancía prohibida…). Yusef quiere
un CRUD:

> "¿Hay algún lugar donde nosotros podamos agregarlos, o te los tendremos que
> estar dando a vos?"

Ya sabe que falta al menos uno: *"solicitado por el cliente para retorno"*. Va a
mandar la lista completa.

Es el mismo patrón de siempre — [[feedback_yusef_crud_first]].

---

### A1-19 · Notas predeterminadas en pre-factura, facturación y caja — **NUEVO**

El modal de motivos que ya existe en `/etiquetar` (retener) lo quiere replicado
en las áreas de cobro:

> "Ese mismo lo vas a crear para que existan predeterminados en prefactura, en caja."

Para qué:

> "Siempre tenemos, digamos, no cumple el mínimo y se le cobró tarifa tal."

Otros ejemplos que dio: *"ese paquete fue enviado al cliente vía KAEX Logistics"*,
*"retirado al crédito por Nilmo Peña"*.

Un clic en vez de escribirlo a mano cada vez. Con opción de detallar manual
también, como el de Miami.

Y esas notas tienen que **verse en el detalle del paquete**, no quedarse en el
documento donde se pusieron:

> "Esa información me tiene que aparecer si yo entro aquí."

---

### A1-20 · En el detalle del paquete, las notas más arriba — **NUEVO**

> "Acá proveedor, carrier, remitente... es más importante que diga notas."

---

### A1-21 · /paquetes muestra la madre y las hijas — **cerrado, no se toca**

Se discutió largo y **quedó como está**. Jorge lo dejó separado (madre + N
hijas) y Yusef lo aceptó:

> "Que quede así como está. Solo tenés que corregir el número de recepción."

La razón para mantenerlo separado la dio él mismo: puede llegar una caja y la
otra no.

Opcional, si sobra tiempo: colapsar en una fila con un expander.

> "Que alguien pueda presionar en algún lado y se baje y saque la segunda línea."

---

### A1-22 · Aviso al retroceder en el pipeline — **YA ESTÁ, aprobado**

Yusef pasó un paquete de "empacado" a "recibido en Miami" y le salió el aviso:

> "Excelente que lo estás previniendo."

---

### A1-23 · Auditoría incompleta — **revisar**

Notó que en algunos campos no aparece quién cambió qué, y en otros sí. Cruza con
[[project_paper_trail_global]]: PR-D1.a solo cubrió `Paquete`.

---

### A1-24 · El PIN **no** va en /etiquetar — **límite de alcance**

Importante dejarlo escrito ahora que Fase 13 está fresca. Jorge preguntó y Yusef
cortó:

> **Jorge:** "¿Este no ocupa PIN?"
> **Yusef:** "No. El PIN es para prefactura. De momento no recuerdo algo que
> ocupe PIN ahí."

Nadie extienda `Autorizacion` a `/etiquetar`.

---

### A1-25 · Origen del paquete (China / Estados Unidos) — **PREGUNTA**

Campo ya marcado en pantalla, sin definir.

> "Lo que marca acá, si es de China no sé qué. Eso es algo que tenemos que ver...
> Como ahorita estamos en Estados Unidos, pero ya va a abrir China."

---

### A1-26 · Tracking secundario — **YA ESTÁ, verificado en vivo**

Se guarda, se muestra en el detalle y **se puede buscar en los filtros**. Yusef
lo probó durante la llamada y funcionó.

---

### A1-27 · Cámara con IA que llene el formulario — **FUTURO**

Es lo que más quiere del proyecto, en sus palabras:

> "Cuando me vayas a trabajar en la inteligencia artificial, lo primero que yo
> quiero es que estos chavos, encima de la mesa de trabajo, tengan la cámara...
> La cosa es que lea la etiqueta y llene este formulario. Es lo que más quiero."

Una cámara colgada de un cable sobre la mesa, que se acerca a la caja, lee la
etiqueta del courier (FedEx, Amazon, etc.) y llena `/etiquetar` solo.

No es para ahora. Sí conviene que el formulario quede alimentable por algo que
no sea un humano tecleando.

---

### A1-28 · Fechas del proyecto — **contexto**

| Cuándo | Qué |
|---|---|
| **Noviembre 2026** | Sistema terminado, "solo con los últimos detalles" |
| **Diciembre 2026** | **No** se arranca — es temporada alta |
| **Enero 2027** | Arranque real, jalando la base de datos que quede de diciembre |

> "Yo sé que para noviembre vas a tener eso, pero mentira que en diciembre vamos
> a iniciarlo. En enero, que baja un poquito."

También pidió cambiar el formato de trabajo:

> "Prefiero que vos vengas. Por eso te dije: hagamos videollamadas, porque en las
> videollamadas estoy obligado a atenderte."

Y Jorge propuso diagramas de proceso, que Yusef aceptó a medias — prefiere
revisar sobre el sistema andando que sobre un diagrama.

---

### Lo que Yusef quedó de mandar

| Qué | Para qué |
|---|---|
| Lista completa de **motivos de retención** | A1-18 |
| Lista de **notas predeterminadas** por área (pre-factura, caja, SAC) | A1-19 |
| **Formato exacto del número de recepción** con el mes | Ver preguntas |
| **Grabaciones de voz** para pre-alerta | A1-10 |
| Elección del **sonido de error** de la lista que le pase Jorge | A1-10 |

---

### Preguntas nuevas para Yusef (se suman al Excel después del envío 3)

1. **Formato del número de recepción.** Dijo que le falta el mes y que ya lo
   había mandado, pero no lo encontró en la llamada:
   > "Lo que le faltaba era el mes en que se recibió... o sea, era la fecha:
   > recibido en Miami tal fecha 2026."

   Hoy es `<PREFIX><AÑO><CONTADOR-6>`. **No se inventa el formato**: hay que
   pedirle el que mandó. Y ojo — cambiarlo toca `NumeroRecepcionCounter`, el
   índice único y todos los números ya generados en staging.

2. **Búsqueda de cliente por sufijo** (A1-14) — con 5 dígitos, ¿cómo desempata?

3. **Origen del paquete** (A1-25) — ¿qué orígenes y qué cambia según el origen?

4. **F8 → F10** (A1-13) — ¿avisamos a Miami del cambio de atajo?

5. **Peso por caja** (A1-17) — ¿N líneas de una vez o botón "agregar"?

6. **Eliminar cajas al bajar la cantidad** (A1-06) — ¿qué pasa si alguna de las
   que se van ya está facturada o entregada?

---

### Cambios que se ocupan — resumen

**BUGs (confirmados en código)**

| ID | Qué | Dónde |
|---|---|---|
| ~~A1-01~~ | ~~Enter envía el formulario en vez de avanzar de campo~~ ✅ **arreglado** | `etiquetar_controller.js` `formKeydown` |
| ~~A1-02~~ | ~~En `/paquetes` el tracking salía dos veces seguidas~~ ✅ **arreglado** | `index.html.erb` col. "N° recepción" — era la vista, no los datos |
| ~~A1-03~~ | ~~F2 no limpia después de un Enter~~ ✅ **arreglado** | era `formTarget.reset()`, no el foco |
| A1-04 | El código de barras no distingue caja 1 de caja 2 | `_etiqueta.html.erb:29` + `paquete.rb:367-395` |
| A1-06 | Cambiar la cantidad de cajas no elimina ni crea las sobrantes | `crear_split!` solo crea |
| A1-08 | "Cambio de servicio" no pregunta a cuál, y no aplica | `/etiquetar` |
| ~~A1-11~~ | ~~La ventana de impresión no se cierra~~ ✅ **arreglado** | `layouts/etiqueta.html.erb` |

**Nuevo**

| ID | Qué |
|---|---|
| A1-07 | Actualizar desde `/etiquetar` con el formulario pre-cargado |
| A1-09 | Modal + sonido cuando el tipo de envío no es el de la sesión |
| A1-10 | Pito de "ya existía", sonido de error, pin antes de los modales, voz de pre-alerta |
| A1-12 | Atajos arriba y abajo |
| A1-15 | Reordenar campos y flujo de Tab |
| A1-17 | Peso y medidas por caja |
| A1-18 | CRUD de motivos de retención |
| A1-19 | Notas predeterminadas en pre-factura, facturación y caja |
| A1-20 | Notas arriba en el detalle del paquete |

**Verificar / decidir**

| ID | Qué |
|---|---|
| A1-05 | Que el sufijo `-1`/`-2` **nunca** toque el tracking |
| ~~A1-13~~ | ~~Unificar guardar en F10~~ ✅ **arreglado** (F8 queda de alias) |
| A1-16 | Que el tercero de texto libre no esté creando clientes |
| A1-23 | `paper_trail` más allá de `Paquete` |
| A1-24 | **No** meter PIN en `/etiquetar` |

**Ya está** — A1-22 (aviso de retroceso), A1-26 (tracking secundario), sesión
por tipo de envío (A1-09 parcial), F4 tercero (A1-15).

**Futuro** — A1-27 (cámara con IA).

---

## Conversación 6 · Audio 2 — monedas, cargos extra y escalonado

Yusef recorriendo su hoja de precios cargo por cargo. **Este audio contesta la
pregunta más grande que teníamos abierta**: la moneda de los diez cargos que
PR-10.i dejó sin cargar porque la leyenda de colores de la hoja nunca se aplicó
a las celdas.

---

### A2-01 · Los precios los ingresa Yusef, no Jorge — **cambia la estrategia**

Lo más importante del audio para el plan de trabajo:

> "No es necesario que vos me crees aquí con los precios. **Los precios los
> ingresamos nosotros.**"

Jorge solo carga **los cuatro** que hacen falta para poder probar:

> "Vos ingresás estos cuatro que están acá. ¿Por qué? Para que podamos usar el
> sistema y probarlo. Después vos me decís que ingresemos los demás nosotros,
> entonces yo pongo a Vanessa o a alguien y lo ingresamos nosotros. Porque eso
> es demasiado trabajo para meterlo vos."

O sea que la respuesta a "faltan 10 cargos por cargar" **no es cargarlos** — es
que el CRUD esté completo y ellos los metan. Mismo patrón de siempre:
[[feedback_yusef_crud_first]].

Esto **cierra** la pregunta ALTA *"la moneda de 10 cargos"* del Excel: ya no
bloquea nada de código.

---

### A2-02 · Regla de fondo: el flete internacional va en dólares, los mínimos en Lempiras

> "Casi todo lo que tiene que ver con servicios de flete, los fletes
> internacionales nuestros... casi todo está en dólares. **A excepción de cuatro
> mínimos**, que están en lempiras."

Y el porqué es competitivo, no contable:

> "Así es la competencia... el que le sigue, que cobra más barato, cobra
> doscientos más impuestos. Yo cobro ciento setenta y tres 91 centavos, o sea
> haciendo 200."

| | Competencia | Compras Express |
|---|---|---|
| Precio de lista | L.200 | L.173.91 |
| + ISV 15% | L.30 | L.26.09 |
| **Total al cliente** | **L.230** | **L.200** |

Por eso el mínimo es **L.173.91** y no un número redondo: es L.200 exactos ya con
impuesto. Confirma que el mínimo está bien cargado y que la regla del ISV
(precio neto, ISV encima) es la correcta.

---

### A2-03 · Monedas de los cargos — **RESUELTAS**

Lo que dijo de cada uno, cruzado contra lo que hay cargado hoy:

| Cargo | Yusef (audio 2) | En el sistema | |
|---|---|---|---|
| **Ajuste** | **USD** — "aquí dice un lempira pero yo lo puse a dólares" | no cargado | ✅ resuelto |
| **Cambio de servicio** | **L.100** — "son los 100 lempiras, yo te lo puse que eran 5" | L.100 | ✅ arreglado (A2-04) |
| **Compras online** | **USD** — "ponerlo 1 USD más impuesto" | USD 1.00 | ✅ coincide |
| **Consolidado en Miami** | **sin costo** — "eso no tiene ningún costo, en cero. Le pusimos algo pero es porque me equivoqué" | no cargado | ✅ resuelto |
| **Entrega local** | **variable** — "a veces hay entregas especiales que no sabemos el costo" | no cargado | ✅ manual |
| **Entrega nacional** | **LPS** — "servicios convencionales, es decir lempiras" | LPS 86.96 | ✅ coincide |
| **Flete** (genérico) | **variable** — "un flete X que hagamos, que no sepamos cómo ingresar" | no cargado | ✅ manual |
| **Flete internacional UPS** | **USD** — "esa es las exportaciones" | USD 1.00 | ✅ coincide |
| **Flete México** | de México a Honduras, "ya le puse los precios" | no cargado | ⚠️ moneda no dicha |
| **Manejo y gastos de destino** | "igual parecido al de ajuste" (y ajuste es USD) | **LPS** 1.00 | ⚠️ ver abajo |
| **Producto ejemplo** ×2 | **borrar** — "no existe" | no cargado | ✅ correcto |
| **Recolecta Miami** | **$35 USD**, con descuentos por cliente | choca con `TarifaRecolecta` | ⚠️ ver A2-06 |
| **Retenido en Miami** | **NO cuesta** — ver A2-05 | no cargado | ✅ resuelto |
| **Retornado de Miami** | **USD**, $5 mínimo / $15 típico | USD 5.00 | ✅ coincide |
| **Servicio de entrada y salida** | **$5 a $10 USD** por paquete | no cargado | ✅ resuelto |

⚠️ **Manejo y gastos de destino** es el único donde el audio y la hoja se
contradicen. La hoja dice textual *"ponerlo lps1 mas isv"* (por eso está en LPS)
y en el audio dice que es *"parecido al de ajuste"*, que es USD. Puede que
"parecido" se refiera a la **naturaleza** del cargo (un trámite variable) y no a
la moneda. **No lo cambié.** Va a la lista de confirmar.

---

### A2-04 · Cambio de servicio: cobraba 3.7× de más — ✅ **ARREGLADO** (PR-C6.1)

| | |
|---|---|
| Yusef en el audio | **L.100** |
| En la hoja | 5 |
| **En el sistema hoy** | **$15 USD ≈ L.373** |

Y no es un cargo que alguien elige a mano: **se auto-genera en nota de débito**
al facturar un paquete con `solicito_cambio_servicio`. O sea que hoy sale solo,
a casi cuatro veces lo que Yusef dice que vale.

Él mismo dijo que lo va a ajustar:

> "Como esto es editable, nosotros lo vamos a cambiar de acuerdo a lo que
> cuadremos al final."

Esto **cierra** la pregunta ALTA *"cambio de servicio: su hoja dice 5, el sistema
cobra $15"* del Excel.

**Arreglo (PR-C6.1).** Queda en `L.100 LPS` con el ISV **adentro**:

| | neto | + ISV |
|---|---|---|
| Antes ($15 USD) | L.324.04 | **L.372.65** |
| Ahora (L.100) | L.86.96 | **L.100.00** exactos |

Va con el ISV adentro al revés que los cinco cargos de la hoja, y es a
propósito: los de la hoja van netos porque ahí dice *"PRECIOS NO INCLUYEN
IMPUESTOS"*, y este número vino del **audio**, donde Yusef habla del precio
final que paga el cliente. Con el flag en `true` el CRUD le muestra **100** —
su número — y `precio_venta_sin_isv` mete los 86.96 a la línea. Es el mismo
criterio que `Tarifa#minimo_monto_con_isv`, que lo deja escribir 200 y guarda
173.91.

Él lo sigue ajustando desde el CRUD: *"como esto es editable, nosotros lo vamos
a cambiar de acuerdo a lo que cuadremos al final"*.

⚠️ **El seed no alcanzaba.** `db/seeds.rb` usa `find_or_create_by!`, así que
corregirlo no toca la fila donde el cargo ya existe — que es justamente donde
importa. Va con `ServiciosExtraPropuesta2026.corregir_cambio_servicio!`, que
`tarifas:sembrar_cargos_2026` ya invoca (y hay tarea suelta
`tarifas:corregir_cambio_servicio` por si hace falta).

**Corrección a lo que decía este doc:** la `NotaDebito` que se auto-crea al
facturar con motivo `cambio_servicio` **no contiene el cargo** — sus líneas son
un *ajuste de flete*. Los L.100 viven en la pre-factura y en la venta, que es
donde se cobra. Quedó un test para que nadie lo asuma al revés y termine
cobrándolo dos veces.

Cubierto por `test/models/cambio_servicio_precio_test.rb` (4 tests) y 5 más en
`servicios_extra_propuesta_2026_test.rb`. Verificado reintroduciendo el $15 —
caen 5.

---

### A2-05 · Retener en Miami **no** tiene costo — **corrección**

> "El retener **no tiene un cobro**. Lo que en realidad tiene un cobro es el
> proceso que le hagamos."

Y el $5 que aparecía era deliberado, pero ya no lo quiere:

> "Fue un error que se dejó. Que cobrábamos $5 por retener en Miami **para que la
> gente se asustara** cuando leyera."

Para qué usan retener de verdad: el cliente quiere saber cuánto mide y pesa
antes de decidir si lo manda aéreo o marítimo. **Medir y pesar no se cobra.**

Lo que sí se cobra es lo que venga después (retornar, entrada y salida, etc.).

Y mencionó que el servicio de consolidación (**CONT**) sí va a existir: el
cliente acumula en Miami y pide que se lo manden todo junto.

---

### A2-06 · Los cargos que faltan definir bien

| Cargo | Lo que dijo | Falta |
|---|---|---|
| **Retornado de Miami** | $5 es el **mínimo**. Con trámite y llevada al correo sube. Si es **USPS** hay que pagar motorista aparte → **$15** | ¿$5 mínimo con escalones, o dos cargos? |
| **Entrada y salida (IN & OUT)** | El cliente recibe en Miami y lo recoge él mismo. "$5 cada uno" por paquete, "de 10 a 5 depende" | El rango — ¿de qué depende? |
| **Recolecta Miami** | "$35 normal, pero hay clientes que tienen descuentos" | Choca con [[project_recolecta_tabla_tarifas]], donde pidió tabla **por zona**. ¿Son dos cosas distintas — recolecta en Miami vs. en Honduras? |
| **Etiqueta internacional** | Servicio que existe dentro de los retornados de Miami | **No está en la hoja ni en el sistema.** "¿La vas a poder agregar después?" → "Sí, necesitamos poder agregar" |

---

### A2-12 · La hoja "actualizada" del 7 de agosto no trae nada nuevo

Yusef mandó `precios por categoria 2026 (1).xlsx` diciendo que era la versión
actualizada. **No lo es.** Se comparó celda por celda contra la del 5 de agosto:

| | Vieja (5 ago) | Nueva (7 ago) |
|---|---|---|
| Valores de las 3 hojas (`Hoja1`, `ACTUAL`, `PROPUESTA`) | idénticos | idénticos |
| Rellenos de las celdas de precio | `theme0` (blanco) | `theme0` (blanco) |
| Celdas de la leyenda D31/D32 | `theme9` / `theme7` | `theme9` / `theme7` |
| `dcterms:modified` | 2026-08-05 21:31 | 2026-08-07 02:20 |

Lo abrió y lo volvió a guardar; los bytes cambian porque Excel reescribe todo,
pero **ninguna celda cambió**.

⚠️ **La leyenda de colores sigue sin aplicarse.** Era la esperanza de que esta
versión resolviera la moneda de los cargos: las celdas de precio siguen en
blanco (`theme0`), y los colores solo están en las dos celdas de la leyenda.
Menos mal que el audio 2 la resolvió hablando (A2-03).

También se confirmó que **la matriz de categorías y los tres tarifarios
escalonados (CER, CEM, CKM) coinciden exactamente** con lo que ya está sembrado
en `lib/tarifas_propuesta_2026.rb`, incluido el split de CKM 13.5–100 lb entre
SPS ($1.90) y TGU ($2.00).

Y siguen faltando **EXPRESS y CKA** en los tarifarios escalonados, tal como
Yusef dijo en el audio (A2-10).

---

### A2-13 · Lo que la hoja sí tenía y nunca habíamos extraído

Revisándola a fondo aparecieron tres cargos con datos **por categoría** que solo
se habían leído de la columna "Precio Normal".

**Recolecta Miami — los descuentos están en la hoja** (fila 24). Esto le pone
números al *"$35 normal, pero hay clientes que tienen descuentos"* del audio:

| Categoría | Precio |
|---|---|
| Precio Normal · Precio Tegus · Shein · Shein TGUS | **35** |
| Clientes Amigos · doTERRA/Farmasi · Mayoristas · Revendedores | **25** |
| Familia · Personal CEC · Sin Cobro Mínimo | 0 |

⚠️ Ojo con los ceros: en esta hoja un 0 viene significando *"sin definir"*, no
*"gratis"* — así está documentado para los mínimos. Pero **Personal CEC sí tiene
precios en todo lo demás**, así que su 0 en recolecta podría ser un descuento
del 100% para el personal. Va a preguntas.

**Servicio de entrada y salida** (fila 27): precio **10**, mínimo **5**, igual
para todas las categorías que pagan. O sea que el *"de 10 a 5 depende"* del
audio **no depende de la categoría** — el 10 es el precio y el 5 el piso. De qué
depende que baje sigue abierto.

**Flete México** (fila 20): solo Precio Normal y Precio Tegus, con precio **5**
y mínimo **6**. ⚠️ El mínimo es **mayor que el precio**, lo cual no tiene
sentido — o el 5 es por libra y el 6 el piso del envío, o hay un error de
tipeo. Va a preguntas.

Nada de esto se carga todavía: la moneda de los tres sigue sin confirmarse, y
además **los precios los mete Yusef** (A2-01).

---

### A2-07 · El CRUD de tarifas ya hace lo que pidió — ✅ **YA ESTÁ**

Yusef describió lo que necesita mostrando el sistema viejo:

> "Cuando lo crees, que yo pueda seleccionar cómo es el cobro: si lempiras o
> dólares."

Y su queja concreta del sistema viejo:

> "Cada vez que queremos modificar un precio mínimo tenemos que modificarlo en
> dólares, y los dólares no cuadran. Yo tengo que venir y cuadrar 173.91."

**Eso ya está resuelto** en `/servicios` (`app/views/servicios/_form.html.erb`):

| Lo que pidió | Dónde está |
|---|---|
| Moneda del precio | `f.select :moneda` — LPS/USD |
| **Moneda del mínimo, independiente** | `f.select :minimo_moneda` |
| Monto mínimo **en el idioma de Yusef** | `minimo_monto_con_isv` — él escribe **200**, la columna guarda **173.91** |
| Si incluye impuestos | `precio_incluye_isv` |
| Mínimo de libras | `minimo_libras` |

El accessor de `tarifa.rb:96-107` es justo el que le quita el dolor de cabeza:
convierte de/hacia el ISV para que nunca tenga que calcular el neto a mano.

Vale enseñárselo en la próxima llamada — él no sabía que ya estaba, y opinó:

> "Yo veo el tuyo mejor en eso, mucho mejor en un montón de cosas."

---

### A2-08 · A los servicios extra les falta el mínimo — **NUEVO**

En el sistema viejo el mínimo era **obligatorio** en cada servicio:

> "Precio mínimo a cobrar, lo tiene obligado."

`Tarifa` sí tiene `minimo_monto` / `minimo_moneda`. **`ServicioExtra` no tiene
ningún campo de mínimo** — sus columnas son `codigo, descripcion, costo,
precio_venta, moneda, precio_incluye_isv, position, activo, notas`.

Y hace falta de verdad: el **retornado de Miami** es exactamente eso — *"$5 es
como un precio mínimo que cobramos"*.

El CRUD de `/servicios_extra` ya tiene moneda y el check de ISV; solo falta el
mínimo.

---

### A2-09 · Escalonado — la regla de redondeo, **confirmada**

La tabla de escalones va en hoja aparte:

> "No supe cómo ponértelo ahí, entonces mejor lo metí acá abajo."

Columnas: **desde – hasta libras · monto en Lempiras con impuesto**. Mínimo
L.200 con impuesto en todas: *"es mínimo doscientos, doscientos, doscientos"*.

Y confirmó la regla de redondeo de libras, que ya teníamos anotada:

> "El uno punto cero nueve **sigue siendo uno**. Uno punto uno ya es **uno y
> medio**. Uno y medio pues uno y medio. Y de **uno punto seis ya sube**."

| Peso real | Se cobra |
|---|---|
| 1.00 – 1.09 | **1.0** |
| 1.10 – 1.59 | **1.5** |
| 1.60 – 2.09 | **2.0** |

Coincide con la regla `.10/.60` de [[project_etiquetar_sesion_y_calc]].

**Se cruzó contra el código y hay dos cosas.**

**1. Hoy el redondeo no se aplica.** `incremento_libras` está en `nil` en las
58 tarifas cargadas, y `redondear_al_incremento` (`tarifa.rb:131-136`) devuelve
el peso tal cual cuando está vacío. O sea que se cobra el peso exacto: 1.09 lb
se cobran como 1.09.

**2. Cuando se active, no va a redondear como Yusef dijo.** La implementación es
un `ceil` puro al múltiplo:

```ruby
((peso / inc).ceil * inc).round(2)
```

Un `ceil` no tiene tolerancia, y la regla de Yusef sí: el `.10` y el `.60` son
justamente los umbrales donde recién sube. Con `incremento_libras = 0.5`:

| Peso | El código | Yusef | |
|---|---|---|---|
| 1.05 | 1.5 | **1.0** | 🔴 cobra de más |
| 1.09 | 1.5 | **1.0** | 🔴 cobra de más |
| 1.10 | 1.5 | 1.5 | ok |
| 1.50 | 1.5 | 1.5 | ok |
| 1.55 | 2.0 | **1.5** | 🔴 cobra de más |
| 1.59 | 2.0 | **1.5** | 🔴 cobra de más |
| 1.60 | 2.0 | 2.0 | ok |

Falla en dos bandas — `.01–.09` y `.51–.59` — y **siempre hacia arriba**. Sobre
un CER de 1.05 lb con mínimo de por medio no se nota, pero sobre un paquete de
40.05 lb son media libra de más cobrada.

Es una **mina**, no un incendio: mientras `incremento_libras` siga en `nil` no
cobra de más. Muerde el día que Yusef active el escalonado — el mismo patrón de
los cuatro errores de plata de PR-10, que estuvieron latentes hasta que se
cargaron las tarifas reales.

La fórmula que sí da la regla de Yusef es un ceil con tolerancia de 0.09:

```ruby
(((peso - Rational(9, 100)) / inc).ceil * inc).round(2)
```

**PREGUNTA antes de implementarla:** Yusef describió la regla solo para
incrementos de media libra. Si mañana crea una tarifa con incremento de 1 lb,
¿la tolerancia sigue siendo 0.09, o es proporcional? No lo inventamos.

---

### A2-10 · Faltan EXPRESS y CKA en la tabla de escalones — **Yusef los agrega**

> "Aquí me faltó el exprés, porque el exprés no lo hemos creado, pero vos debés
> crearlo para yo podérselo agregar."
> "Y aquí faltó el CKA también, que no lo tengo analizado."

No hay que esperarlos: con el CRUD de `/servicios` andando, él los mete. Lo que
sí hay que confirmar es que el catálogo de **tipos de envío** tenga EXPRESS y
CKA dados de alta para poder colgarles tarifas.

---

### A2-11 · Tarifa editable: supervisor **y** área administrativa — **matiz de Fase 13**

> "Tarifa editable con autorización de supervisor o jefe **cuando están en
> prefactura**, pero también eso es **editable por el área administrativa**."

Son dos caminos distintos y conviene no confundirlos:

| Quién | Dónde | Cómo |
|---|---|---|
| Supervisor / jefe | En la **pre-factura**, sobre una línea concreta | **PIN** + queda la autorización registrada (Fase 13) |
| Área administrativa | En el **catálogo** `/servicios` | Edición normal del precio de lista, sin PIN |

Lo que Fase 13 protege es el precio **de una venta**, no el catálogo.

---

### Preguntas que este audio CERRÓ

| Pregunta del Excel | Cómo quedó |
|---|---|
| Moneda de los 10 cargos | ✅ Resueltas casi todas (A2-03). Y ya no bloquea: los carga Yusef (A2-01) |
| Cambio de servicio: ¿5 o $15? | ✅ **L.100**, editable por ellos (A2-04) |
| Redondeo de libras | ✅ Confirmada la regla `.10/.60` — y el código **no** la cumple (A2-09) |

### Preguntas que quedan (se suman a las de audio 1)

7. **Manejo y gastos de destino** — la hoja dice LPS, el audio sugiere USD (A2-03)
8. **Recolecta** — ¿el $35 de Miami y la tabla por zona son dos cosas distintas? (A2-06)
9. **Retornado de Miami** — ¿$5 mínimo con escalones, o $5 y $15 son dos cargos? (A2-06)
10. **Entrada y salida** — ¿de qué depende que sea $5 o $10? (A2-06)
11. **Flete México** — ¿en qué moneda? (A2-03)
12. **Etiqueta internacional** — ¿precio y en qué moneda? (A2-06)
13. **Tolerancia del redondeo** — el `.10/.60` es para incrementos de media
    libra. Si crea una tarifa con incremento de 1 lb, ¿la tolerancia sigue
    siendo 0.09 o es proporcional? (A2-09)
14. **Recolecta: el 0 de Personal CEC** — ¿es descuento del 100% o "sin
    definir"? Tiene precios en todo lo demás (A2-13)
15. **Flete México** — el mínimo (6) es mayor que el precio (5). ¿El 5 es por
    libra y el 6 el piso del envío, o hay un error de tipeo? (A2-13)
16. **La hoja de precios** — la versión del 7 de agosto es idéntica a la del 5.
    Si pensaba mandar cambios, no llegaron (A2-12)

---

### Audio 2 — cambios que se ocupan

**Urgente**

| ID | Qué |
|---|---|
| ~~A2-04~~ | ~~Cambio de servicio cobraba $15 (≈L.373)~~ ✅ **arreglado** — L.100 exactos |
| A2-09 | **El redondeo de libras cobra de más en `.01–.09` y `.51–.59`** — latente hasta que se active `incremento_libras` |

**Nuevo**

| ID | Qué |
|---|---|
| A2-08 | Campo de **mínimo** en `ServicioExtra` (+ en su CRUD) |
| A2-06 | Dar de alta **etiqueta internacional** como servicio |
| A2-10 | Confirmar que EXPRESS y CKA existen como tipo de envío |

**Corregir el catálogo** (lo hace Yusef, pero hay que dejarle el camino)

| ID | Qué |
|---|---|
| A2-05 | Retener en Miami **no** cuesta — quitar el cobro |
| A2-03 | Consolidado en Miami en **cero** |
| A2-03 | Borrar los "producto ejemplo" |

**Verificar**

| ID | Qué |
|---|---|
| A2-11 | Que el PIN cubra la línea de pre-factura y **no** el catálogo |

**Ya está** — A2-07 (el CRUD de tarifas con moneda + mínimo con ISV ya hace todo
lo que pidió; solo hay que enseñárselo).

**Ya no aplica** — cargar los 10 cargos pendientes de PR-10.i: los mete Yusef
(A2-01).

---

## Conversación 6 · Imágenes — las notas a mano de Jorge

Tres páginas escritas **durante la misma reunión**, mientras Yusef probaba el
sistema. No son requerimientos nuevos: son el apunte de Jorge en el momento, lo
que las vuelve un contraste independiente contra lo que se sacó de los audios.

**El cruce da 1:1.** Todo lo que está en las notas aparece en `A1-nn`, y aparece
**un solo item nuevo** (el segundo pito), que ya quedó incorporado a A1-10.

---

### Página 1 — el teclado

Transcripción:

```
pág 1
1) /etiquetar
2) código cliente
   leer de derecha a izq
Y
el ~~Tab~~ presiona enter → moverse al siguiente

3) quitar Pre-Alerta, Pre-Factura

   pita
   1) pre-alerta
   2) que ya existía

poner ambos lados  Botones
pistola enter
F2 → limpiar todo el formulario
→ No autograbar etiqueta
```

| Nota | Item |
|---|---|
| `código cliente leer de derecha a izq` | **A1-14** |
| `el ~~Tab~~ presiona enter → moverse al siguiente` | **A1-01** |
| `pistola enter` | **A1-01** |
| `No autograbar etiqueta` | **A1-01** |
| `F2 → limpiar todo el formulario` | **A1-03** |
| `quitar Pre-Alerta, Pre-Factura` | **A1-15** |
| `poner ambos lados — Botones` | **A1-12** |
| `pita: 1) pre-alerta 2) que ya existía` | **A1-10** ← el único item nuevo |

Detalle que vale: Jorge **tachó "Tab" y escribió "enter"** en el momento. Eso
fija que la regla no es "que Tab funcione" sino que **Enter haga lo que hace
Tab** — que es exactamente donde está el bug (A1-01).

Y el punto 1 dice `/etiquetar`, no `/label`: es el apunte del que salió el
renombre que ya se hizo.

---

### Página 2 — dropdowns, tercero y la columna de warehouse

Transcripción:

```
pág 2   seleccionar
→ ~~Grabar~~ con tab o enter
  de los dropdowns

Tercero
  2 formas de crear
  etiquetas → warehouse receipts
→ Texto
→ o selección

Tab Tercero → que pase Descripción
Notas → arriba de carrier

columna de warehouse
No de recepción
```

| Nota | Item |
|---|---|
| `~~Grabar~~ seleccionar con tab o enter de los dropdowns` | **A1-01** |
| `Tercero: texto o selección` | **A1-16** |
| `Tab Tercero → que pase Descripción` | **A1-15** |
| `Notas → arriba de carrier` | **A1-15** |
| `columna de warehouse / No de recepción` | **A1-02** ✅ ya arreglado |

Acá también hay una tachadura que dice todo: Jorge escribió **"Grabar"**, lo
tachó y puso **"seleccionar"**. Es la corrección que Yusef le hizo en voz alta:

> "O sea, grabar, no grabar — **seleccionar**."

Y `columna de warehouse / No de recepción` es exactamente el bug que se arregló
en este bloque: la columna tenía que mostrar el número de warehouse y estaba
mostrando el tracking.

`etiquetas → warehouse receipts` bajo "Tercero" es la regla A1-16: el tercero
escrito a mano vive **en el warehouse receipt** y no se guarda en ninguna base
de datos de clientes.

---

### Página 3 — impresión, cambio de servicio y sonidos

Transcripción:

```
página 3
etiquetar
→ cerrar ventana y regresar etiquetar
────────────
cambio de servicio → CER a CKM  no funciona

→ Cambio de servicio → ¿?
  pregunte qué servicio → modal

→ Rebajar
Nota
────────────
Audios / sonidos → cuando se escanea
                   escanea
                   código de cliente
→ Diff session tiene que tener una alerta sonido
```

| Nota | Item |
|---|---|
| `cerrar ventana y regresar etiquetar` | **A1-11** |
| `cambio de servicio → CER a CKM no funciona` | **A1-08** |
| `pregunte qué servicio → modal` | **A1-08** |
| `Rebajar` | **A1-04** — el rebaje de inventario al escanear en San Pedro |
| `Nota` | **A1-19 / A1-20** |
| `sonidos: cuando se escanea · código de cliente` | **A1-10** |
| `Diff session tiene que tener una alerta sonido` | **A1-09 + A1-10** |

`CER a CKM no funciona` es el caso exacto que Yusef reprodujo: marcó el cambio,
guardó, y el tipo de envío se quedó en CER. Sirve como caso de prueba concreto
cuando se arregle A1-08.

---

### Lo que el cruce confirma

1. **No se perdió nada de los audios.** Los 15 apuntes de las tres páginas caen
   todos dentro de `A1-01` … `A1-20`.
2. **Un solo item nuevo:** el segundo pito (`que ya existía`), incorporado a
   A1-10.
3. **Las notas no contradicen nada** de lo documentado.
4. Las tachaduras (`Tab`→`enter`, `Grabar`→`seleccionar`) son las dos
   correcciones que Yusef hizo en vivo, y las dos apuntan al mismo bug: **A1-01**.

Y una lectura de prioridad que sale sola: de los 15 apuntes, **cinco** son A1-01
o su consecuencia directa. Es el que hay que arreglar primero.

---

## Próximos Pasos

1. **Conversación 2:** Login, Logout, Creación de usuarios y roles — por documentar
2. **Conversación 3:** Detalle de Paquete Interno + Warehouse Receipt — ✅ documentada arriba, preguntas del bloque PR-D todas resueltas
3. **Conversación 4:** ✅ documentada arriba — franja de contexto operativo (PR-9)
4. **Conversación 5:** ✅ documentada arriba — tarifas, mínimos y etiqueta (PR-10)
5. **Conversación 6:** ✅ documentada completa — audios 1 y 2 más las 3 páginas de notas (`A1-01` … `A1-28`, `A2-01` … `A2-11`, cruce `N`). Sigue: armar el plan de PRs y llevarle las 13 preguntas a Yusef
