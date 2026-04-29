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

### Preguntas aún pendientes (al cliente)

**Bloque PR-D3 — única pendiente:**
- 14b. **Empresa de transporte (ej. EPN = Pronto Cargo)** cuando un paquete cambia de manifiesto: ¿el detalle del paquete muestra la empresa **del manifiesto actual** (heredamos automático y cambia si el paquete cambia de manifiesto), o la **empresa original** (guardamos en el paquete y queda fija aunque el manifiesto cambie)?

**Bloque PR-D4 — botones:**
- 15. Re-imprimir etiquetas: ¿todas las cajas o solo la actual?
- 16. Botón "Refrescar": F5 o algo específico (ej. recargar solo la bitácora).

**General:**
- 17. Manifiesto formato `MM2026000001`: ¿en PR-D1, PR aparte, o postergar?

---

## Próximos Pasos

1. **Conversación 2:** Login, Logout, Creación de usuarios y roles — por documentar
2. **Conversación 3:** Detalle de Paquete Interno + Warehouse Receipt — ✅ documentada arriba (en curso, ~6 preguntas pendientes)
3. **Conversación 4:** Pendiente — visita al cliente
4. Después de las 4 conversaciones: crear plan de implementación completo por módulo
