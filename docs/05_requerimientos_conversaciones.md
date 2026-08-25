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

| # | Fecha | Tema | Estado |
|---|-------|------|--------|
| 1 | Mar 2026 | Pre-alertas, tareas, audio, notas, fotos, volumen | ✅ Documentada |
| 2 | — | Login, Logout, Usuarios y Roles | ⏳ Parcial — los 9 roles están definidos; los permisos por operación llegan en el Excel que Yusef ofreció en `A7-28` (`RP-35`) |
| 3 | 2026-04-29 | Detalle de Paquete Interno + Warehouse Receipt | ✅ Documentada (bloque `PR-D`) |
| 4 | 2026-08-01 | Franja de contexto operativo | ✅ Documentada (`PR-9`) |
| 5 | 2026-08-02 | Tarifas, mínimos y etiqueta | ✅ Documentada (`PR-10`) |
| 6 | 2026-08-08/10 | Prueba en vivo de `/etiquetar` — 4 audios + 4 anexos | ✅ Documentada (`A1-*`…`A4-*`, `RP-01`…`RP-23`) |
| 7 | 2026-08-12 | Revisión del PDF de procesos, de punta a punta | ✅ Documentada (`A7-01`…`A7-34`, abre `RP-31`…`RP-36`) |

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

### A1-04 · El código de barras no distinguía caja 1 de caja 2 — ✅ **ARREGLADO** (PR-C6.6)

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

**Arreglo (PR-C6.6).** `etiqueta_codigo_barras` arma el payload con dos reglas:

1. **Es el warehouse, nunca el tracking.** Sin número de recepción devuelve
   `nil` y **no se imprime barcode**, en vez de caer al tracking como antes.
   Una etiqueta sin código es un problema visible; una con el código
   equivocado se escanea mal en San Pedro y nadie se entera.
2. **Lleva el sufijo de caja** cuando el tracking se dividió. El mismo texto va
   impreso debajo, para poder teclearlo si la etiqueta viene rayada.

⚠️ **Y lo que hubiera cambiado un bug por otro:** el scope de búsqueda usa
`numero_recepcion ILIKE`, así que escanear `RMI0002026000042-2` daba **cero
resultados** contra la recepción `RMI0002026000042`. `Paquete.buscar` ahora
parsea el sufijo y cae **en la caja exacta**. Si esa caja no existe, busca por
el número madre en vez de devolver vacío — puede ser una etiqueta de una caja
que se eliminó, o un tracking que casualmente termina en `-2`.

Y la contraparte, igual de importante:

### A1-05 · El sufijo `-1`, `-2` va en la recepción, **nunca** en el tracking — **regla**

Es el error que arrastraba el sistema viejo y que confundió a todo el mundo:

> "El tracking él le agregaba un 2, y al warehouse él le agregaba un 2 y el 1."

> "Este -1 y -2 al tracking no es necesario ponérselo."

El tracking es del courier y no se toca. La única excepción es el sufijo
`A`/`B`/`C` para trackings **duplicados de verdad**, que es otra cosa
(`next_duplicate_suffix`).

---

### A1-06 · Cambiar la cantidad de cajas no eliminaba las sobrantes — ✅ **ARREGLADO** (PR-C6.7)

Yusef lo reprodujo dos veces en vivo:

- Un paquete con 3 cajas → lo editó a 2 → **quedaron las 3**.
- Después lo subió a 5 → quedaron los registros viejos mezclados con los
  nuevos: "aquí dice dos y aquí dice que son cinco".

`crear_split!` solo sabe **crear** N cajas. No hay una operación de *ajustar* de
N a M sobre un split que ya existe.

La regla que acordaron es simple: la cantidad nueva manda.

> **Jorge:** "Si tienes cinco y lo quieres cambiar a dos, solo deberían quedar los dos."
> **Yusef:** "Eliminar lo otro. Ajá."

**Arreglo (PR-C6.7):** `Paquete.ajustar_split!`. Bajar elimina las cajas de
`numero_caja` mayor; subir crea las nuevas con el mismo número madre.

**Guarda dura, confirmada por Jorge:** si alguna caja a eliminar ya está
facturada, pre-facturada o entregada, la operación falla **entera** y no toca
nada — borrarla descuadraría la venta en silencio. Mira el estado **y** los FKs
de cobro, porque un paquete puede tener `pre_factura_id` sin que su estado lo
diga todavía.

Qué hacer en ese caso sigue siendo pregunta abierta de Yusef; hasta que
conteste, bloquear con un error explícito es lo conservador.

---

### A1-07 · Miami actualiza desde /etiquetar, no desde /paquetes — ✅ **HECHO** (PR-C6.10)

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

**Arreglo (PR-C6.10):** `/etiquetar?paquete_id=X` recarga el mismo formulario
con lo que el paquete ya tiene, y F9/F10 guardan encima. "Es actualización"
deja de navegar a `/paquetes/:id/edit`.

**La línea divisoria se respeta en el servidor**, no solo en la UI:
`paquete_params` no permite `estado`, y hay un test que lo fija. Cambiar la
cantidad de cajas delega en `ajustar_split!` (A1-06), con su bloqueo si alguna
ya se cobró.

**Decisión tomada, confirmada por Jorge:** al actualizar **la sesión no le pisa
el tipo de envío** al paquete. Si es CEM y el operario está en sesión CER,
corregirle el peso no puede convertirlo en CER — la sesión manda al *crear*.
El cambio de servicio sigue siendo la excepción explícita.

---

### A1-08 · Marcar "cambio de servicio" no preguntaba a cuál — ✅ **ARREGLADO** (PR-C6.8)

> "En etiquetar, al marcar cambio de servicio no está, no pregunta qué tipo de
> servicio."

Y cuando lo forzó por otro camino y guardó, **el tipo de envío no cambió**: se
quedó en CER. O sea que además de no preguntar, no aplica.

Jorge propuso un modal. Yusef no se casa con la forma, sí con la velocidad:

> "No sé, lo que funcione bien: solo darle click, yo doy click y click y ya va.
> Lo que vos creas que te funcione bien, que no cargue y que sea rápido."

**Arreglo (PR-C6.8):** el checkbox adopta el patrón `checkbox-modal` que ya usa
Retener — el propio `checkbox_modal_controller.js` lo tenía documentado como
patrón para "Cambio de Servicio". Al marcarlo abre un `<dialog>` que pregunta
el destino, y al guardar **el tipo de envío cambia de verdad**.

Se agregó `paquetes.tipo_envio_anterior_id` para dejar rastro. No es adorno: el
cambio **genera un cargo automático** en la pre-factura, y cuando el cliente
reclame hay que poder decirle de qué a qué se movió (`cambio_servicio_label`
devuelve `"CER → CKM"`).

Dos detalles que se resolvieron implementándolo:

- **No se usa `errors.add`** para el caso "marcó el flag y no eligió destino":
  el `valid?` que corre adentro de `save` limpia los errores, así que el
  paquete se guardaba igual — a medias, con el flag prendido sobre el tipo
  viejo. Se corta antes de guardar. Es el mismo tropiezo que ya había pasado
  con el cuatro-ojos de las notas.
- **Elegir el mismo servicio de la sesión no marca cambio**: no es un cambio,
  así que no cobra cargo ni ensucia el rastro.

---

### A1-09 · Alerta cuando el paquete no es del tipo de envío de la sesión — ✅ **HECHO** (PR-C6.9)

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

⚠️ **Lo que este doc no había visto: hoy se grababa bajo el tipo equivocado, en
silencio.** `create_single` hace `@paquete.tipo_envio_id = @tipo_envio_sesion.id`
**incondicional**, así que un paquete con pre-alerta CEM escaneado en sesión CER
se guardaba como CER sin que nadie se enterara. El modal es la mitad visible;
**el rechazo del servidor es la mitad que cobra bien**.

**Arreglo (PR-C6.9):** `conflicto_con_la_sesion` rechaza en el servidor, y el
front avisa antes con sonido feo y un banner con las dos salidas acordadas. El
**cambio de servicio (A1-08) es la excepción explícita** — ahí el operario
declaró que el paquete sale de la sesión.

Los sonidos que entraron con esto (A1-10): el pito de **"ya existía"** (el modal
de duplicado abría mudo) y el **feo** para el conflicto de tipo. `audio#error`
ya existía sin cablear.

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
| El tracking **ya existía / ya fue usado** | pito distinto | ✅ PR-C6.9 |
| **Error** — tipo de envío distinto al de la sesión | sonido feo | ✅ PR-C6.9 · tres opciones en `PR-275` |
| **Antes** de que salga cualquier modal | pin | ✅ **de verdad** desde `PR-275` — ver abajo |

> ⚠️ **Esta última decía ✅ desde `PR-C6.16` y no era cierta.** El evento
> `etiquetar:modalAbierto` estaba cableado en la vista y **nadie lo disparaba**:
> el modal de sucursal de retiro y el del PIN del supervisor abrieron mudos
> durante meses. Un cable suelto en Stimulus no tira error ni ensucia la
> consola — simplemente no suena, y el operario está mirando la pistola.
>
> Es el mismo bug que Yusef ya había reportado una vez (*"el modal de duplicado
> abría mudo"*), reaparecido en otros dos modales.
>
> `PR-275` lo arregla y deja dos lints para que no vuelva:
> `test/lint/sonidos_cableados_test.rb` verifica que **ningún modal de las
> pantallas de escaneo abra sin sonar** —método por método, porque con dos
> modales en el mismo archivo un chequeo global no agarra que le borren el
> sonido a uno— y que cada `audio#accion` nombre un método que existe.
>
> Salió también que el modal de configuración **probaba sonidos que no eran los
> que suenan**: el botón rotulado "Pre-alerta" tocaba el de «ya existía», y el
> de pre-alerta de verdad —el que suma la voz— no tenía botón. La lista ahora
> sale de `SonidosDeEscaneo::BOTONES` y hay lint que la confronta contra el
> cableado real.

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

### A1-12 · Los atajos también arriba, no solo abajo — ✅ **HECHO** (PR-C6.11)

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

### A1-14 · Buscar cliente por los últimos dígitos del código — ✅ **HECHO** (PR-C6.14b)

> "El rollo de los códigos de cliente actuales es que tienen el `C00002867`.
> Actualmente el sistema lee de derecha a izquierda."

En el sistema viejo escriben solo `2867`, o hasta un solo dígito, y cae. Es
búsqueda por **sufijo**, no por prefijo.

> "Eso es algo que ya trabajan así, y si se los cambio... solo le ponían el dos."

Contexto: los códigos viejos son de 4 dígitos y los nuevos de 5. **Los viejos no
se migran** — se quedan como están.

**Encontrar ya funcionaba** desde PR-10.f: `codigo ILIKE '%2867%'` matchea el
sufijo, y los ceros a la izquierda ya se ignoraban (`C002 == C2 == 2`). Lo que
faltaba era el **orden** — que era justamente la pregunta abierta: con códigos
de 5 dígitos, teclear `6` trae decenas y el que uno quiere queda enterrado.

**Arreglo (PR-C6.14b):** `Cliente.priorizar_codigo` ordena por

1. el código que **es** ese número, ignorando ceros (`6` → `C00006`),
2. el que **termina** en ese número (`2867` → `C00002867`),
3. el resto.

No inventa política: hace confiable exactamente lo que él describió. Y solo
aplica cuando el término trae dígitos — buscar por nombre queda como estaba.

⚠️ **Faltaba la mitad del front (PR-C6.16).** El autocomplete tenía un mínimo
de **2 caracteres**, así que teclear un solo `2` nunca abría la lista — que es
exactamente lo que Yusef describió. Lo encontró Jorge probándolo: *"veo que si
pongo 2 no me sale María"*.

Ahora un **dígito** suelto busca; una **letra** suelta no, porque buscar "a"
devolvería la cartera entera y el dropdown sería ruido.

La preselección que Yusef pidió **ya estaba**: `renderDropdown` deja el primer
ítem activo, así que Enter lo toma sin tocar el mouse.

---

### A1-15 · Orden de campos y navegación — ✅ **HECHO** (PR-C6.11)

Lo revisaron campo por campo:

| Cambio | Detalle |
|---|---|
| **Notas internas** sube | Arriba del cuadro de carrier/proveedor/remitente |
| **Carrier, proveedor y remitente** bajan | Al cuadro de abajo — "es parte de lo que van a llenar" |
| **Pre-alerta y pre-factura** se van de `/etiquetar` | "Eso no tiene nada que ver con ellos" — Jorge confirmó que quedaron del inicio |
| Tab desde **tercero** → descripción | Y si no activó tercero, de cliente → descripción directo |
| **F4** activa el tercero | ✅ ya está (`etiquetar_controller.js:50-55`) |

---

### A1-16 · El cliente tercero no se guarda en ninguna base de datos — ✅ **HECHO** (PR-C6.14)

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

**El diagnóstico de este doc estaba a medias.** Decía "verificar que el texto
libre no esté creando clientes". La verificación pasa —`tercero_id` solo se
asigna eligiendo un `Cliente` que ya existe— pero **el texto libre no existía**,
así que a un tercero fuera de la cartera no se le podía poner el nombre en la
etiqueta. Y ese es el caso normal.

**Arreglo (PR-C6.14):** columna `paquetes.tercero_nombre`. Lo que se escribe
vive en **ese paquete** y no crea ningún cliente — hay un test que mide
`Cliente.count` para fijarlo.

`tercero_display` resuelve las dos fuentes con el catálogo mandando: si alguien
eligió un cliente de verdad, ese nombre es el bueno. En el detalle se muestra
**sin link ni código y con la aclaración "solo en este paquete"**: no es un
`Cliente` y no debe parecerlo.

Queda pendiente la cartera del revendedor (el caso Carlos Reyes): hoy no existe
ni el flag `revendedor` ni la cartera, y el buscador actual mira **todos** los
clientes.

---

### A1-17 · Peso y medidas por caja — ✅ **HECHO** (PR-C6.17)

> "Sinceramente sí se ocuparía hacerle esa mejora: ponerle cantidad dos y aquí
> te pregunta dos veces."

Si son 2 cajas, el formulario tiene que pedir peso y medidas **de cada una**. Hoy
solo pide una línea.

Dos formas, y dejó elegir:

- N líneas de una vez, según la cantidad
- Un botón "agregar" que va sumando de a uno y limpia entre cada uno

> "Como le importa que son dos, te da esa opción para dos. Al menos vos lo
> cambias a tres."

**Parecía chocar con el modal de F9**, y por eso quedó documentado antes de
implementarse: la cantidad recién se sabe al apretar F9, así que no se pueden
pedir N pesos antes.

**La contradicción se disuelve pidiéndolos en ese mismo modal.** Ahí ya se
pregunta la cantidad, y Yusef revalidó ese flujo en esta misma reunión — *"le
voy a poner dos, ahí está una y dos, excelente"*. Así no se deshace nada de lo
aprobado en PR-4.

**Primer arreglo (PR-C6.17):** las filas se pusieron dentro del modal de F9,
que es donde se preguntaba la cantidad.

**Corrección (PR-C6.18b).** Jorge lo probó y fue directo: **"el F9 era como
confuso"**. Tenía razón, y el motivo se ve al mirar la pantalla: el formulario
mostraba **"Cant. Productos"** —que es cuántos artículos vienen adentro— y
parecía el campo que mandaba, mientras el que de verdad divide el tracking en
bultos estaba escondido detrás de una tecla.

Son dos campos distintos y nadie lo podía adivinar:

| Campo | Qué es |
|---|---|
| **Cant. Productos** | cuántos artículos vienen adentro — dato de contenido |
| **Cant. Cajas** | en cuántos bultos **físicos** se divide el tracking |

Ahora la cantidad de cajas vive **en el formulario**, junto al peso y las
medidas, con las filas por caja debajo — que es exactamente donde Yusef la
señaló: *"acá sería cantidad de paquetes o productos, y aquí el peso de cada
quien"*. **F9 vuelve a ser solo guardar e imprimir.**

Las filas nacen precargadas con lo que ya escribió arriba: si las cajas son
parecidas basta con Enter, y solo se tocan las que difieren.

Vive en `cajas_controller.js` y no dentro de `etiquetar` porque el partial
`shared/_peso_medidas_calc` se usa en **dos** pantallas —`/etiquetar` y
`/entrega_personal`— y las dos crean splits. Jorge preguntó si se podía unificar
el componente: **ya lo estaba** desde PR-10.b; lo que faltaba era que el campo
de cajas viviera ahí.

Del lado del servidor, `crear_split!` acepta `por_caja:` con overrides. Solo se
aceptan esos cuatro campos: el resto del paquete es el mismo para todas —mismo
tracking, mismo cliente, mismo contenido— y lo único que cambia físicamente es
cuánto pesa y mide cada bulto. Va con test.

Lo que arreglaba de fondo: antes las N cajas nacían con el **mismo peso**, así
que un tracking con una caja de 5 lb y otra de 30 se facturaba como dos de 5 —
o como dos de 30, según cuál hubieran escrito. Las dos están mal, y el peso
volumétrico salía igual de mal porque es derivado de las medidas.

---

### A1-18 · Motivos de retención editables — ✅ **APROBADO EN VIVO** (A3-11), falta la lista

Hoy los motivos están fijos (paquete dañado, mercancía prohibida…). Yusef quiere
un CRUD:

> "¿Hay algún lugar donde nosotros podamos agregarlos, o te los tendremos que
> estar dando a vos?"

Ya sabe que falta al menos uno: *"solicitado por el cliente para retorno"*. Va a
mandar la lista completa.

Es el mismo patrón de siempre — [[feedback_yusef_crud_first]].

---

### A1-19 · Notas predeterminadas en pre-factura, facturación y caja — ✅ **HECHO** (PR-C6.13)

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

**Arreglo (PR-C6.13):** el picker `shared/_plantillas_notas` se renderiza en
pre-factura (alta y edición) y en la apertura de caja, y el detalle del paquete
muestra una sección **"Notas de facturación"** con lo que se escribió en su
pre-factura y en su factura.

Lo segundo es lo que importa para servicio al cliente: es lo que necesitan
cuando el cliente llama a preguntar por qué le cobraron algo.

El CRUD de plantillas (`PlantillaNotaCliente`) y el `plantilla_picker`
**ya existían** — faltaba usarlos en cobros.

---

### A1-20 · En el detalle del paquete, las notas más arriba — ✅ **HECHO** (PR-C6.11)

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

### A1-23 · Auditoría incompleta — ✅ **HECHO** (PR-C6.15)

> "Auditar quién... en este no, fíjate, pero en otros campos sí. No sé si es
> que se lo quitó o no había."

**Tenía razón a medias, y este doc lo diagnosticó al revés.** Decía que faltaba
extender `paper_trail` más allá de `Paquete`. **La captura no era el problema**:
`has_paper_trail` está en **41 modelos**. Lo que faltaba era *verlo*.

Lo único con "quién" visible eran los cambios de **estado**, que llevan su
propia columna `fecha_<estado>_by_user_id`. Por eso unos campos sí y otros no —
exactamente lo que él notó.

**Arreglo (PR-C6.15):** sección "Historial de cambios" en el detalle del
paquete, con cuándo, quién y qué cambió. Los ids se resuelven a nombres (un
`tipo_envio_id: 4 → 7` no le dice nada a nadie), los campos derivados y
`updated_at` se filtran, y un cambio sin usuario dice "Sistema" en vez de un id
suelto.

---

### A1-24 · El PIN **no** va en /etiquetar — **límite de alcance**

Importante dejarlo escrito ahora que Fase 13 está fresca. Jorge preguntó y Yusef
cortó:

> **Jorge:** "¿Este no ocupa PIN?"
> **Yusef:** "No. El PIN es para prefactura. De momento no recuerdo algo que
> ocupe PIN ahí."

Nadie extienda `Autorizacion` a `/etiquetar`.

---

### A1-25 · Origen del paquete (China / Estados Unidos) — ✅ **CERRADA** (RP-19)

> ⚠️ **Ojo con la corrección.** `PR-C6.38` lo resolvió derivándolo de la
> sucursal de recepción y lo documentó como **informativo**. Yusef contestó que
> **entra en el cobro** — *"se utiliza para el cobro en Entrega Personal o en
> PreFactura"*. La derivación estaba bien; la conclusión no. Ver `RP-19`.

Campo ya marcado en pantalla, sin definir.

> "Lo que marca acá, si es de China no sé qué. Eso es algo que tenemos que ver...
> Como ahorita estamos en Estados Unidos, pero ya va a abrir China."

---

### A1-26 · Tracking secundario — **A MEDIAS** (matizado por A3-09)

Se guarda, se muestra en el detalle y **se puede buscar en los filtros**. Yusef
lo probó durante la llamada y funcionó.

> ⚠️ **Matizado el 2026-08-08 (A3-09).** Lo que estaba era el *display* y el
> filtro de `/paquetes`. La **búsqueda del escaneo** no lo miraba:
> `check_tracking` —el endpoint que usa la pistola en /etiquetar— hacía
> `where(tracking: valor)` sobre una sola columna. Yusef: *"el sistema debe
> buscar en esto también, debe buscar en la base, y **eso no estaba**"*. Tenía
> razón. Arreglado en `PR-C6.21`.

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
| ~~A1-04~~ | ~~El código de barras no distingue caja 1 de caja 2~~ ✅ **arreglado** | `etiqueta_codigo_barras` + parseo en `Paquete.buscar` |
| ~~A1-06~~ | ~~Cambiar la cantidad de cajas no elimina ni crea las sobrantes~~ ✅ **arreglado** | `Paquete.ajustar_split!` |
| ~~A1-08~~ | ~~"Cambio de servicio" no pregunta a cuál, y no aplica~~ ✅ **arreglado** | modal + `aplicar_cambio_servicio` |
| ~~A1-11~~ | ~~La ventana de impresión no se cierra~~ ✅ **arreglado** | `layouts/etiqueta.html.erb` |

**Nuevo**

| ID | Qué |
|---|---|
| ~~A1-07~~ | ~~Actualizar desde `/etiquetar` con el formulario pre-cargado~~ ✅ **hecho** |
| ~~A1-09~~ | ~~Modal + sonido cuando el tipo de envío no es el de la sesión~~ ✅ **hecho** |
| A1-10 | Pito de "ya existía", sonido de error, pin antes de los modales, voz de pre-alerta |
| ~~A1-12~~ | ~~Atajos arriba y abajo~~ ✅ **hecho** |
| ~~A1-15~~ | ~~Reordenar campos y flujo de Tab~~ ✅ **hecho** |
| A1-17 | Peso y medidas por caja |
| A1-18 | CRUD de motivos de retención |
| ~~A1-19~~ | ~~Notas predeterminadas en pre-factura, facturación y caja~~ ✅ **hecho** |
| ~~A1-20~~ | ~~Notas arriba en el detalle del paquete~~ ✅ **hecho** |

**Verificar / decidir**

| ID | Qué |
|---|---|
| ~~A1-05~~ | ~~Que el sufijo `-1`/`-2` **nunca** toque el tracking~~ ✅ **con test de regresión** |
| ~~A1-13~~ | ~~Unificar guardar en F10~~ ✅ **arreglado** (F8 queda de alias) |
| ~~A1-16~~ | ~~Que el tercero de texto libre no esté creando clientes~~ ✅ **hecho** — no existía, se construyó |
| ~~A1-23~~ | ~~`paper_trail` más allá de `Paquete`~~ ✅ **hecho** — faltaba mostrarlo, no capturarlo |
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

### A2-14 · La hoja del 8 de agosto — esta sí trae cambios

Tercera versión (`precios por categoria 2026 (2).xlsx`, modificada 16:56). A
diferencia de la del 7, **esta sí cambió celdas**. Solo la hoja PROPUESTA;
`ACTUAL` y `Hoja1` siguen idénticas.

**1. Consolidando en Miami pasa de 1 a 0** (Precio Normal y Precio Tegus).

Es Yusef corrigiendo en la hoja lo que ya había dicho en el audio: *"eso no
tiene ningún costo, en cero. Eso le pusimos aquí algo, pero es porque me
equivoqué"*. No hay nada que cargar — el cargo no estaba sembrado.

**2. El primer escalón pasa de "DE 0 A 1 LBS" a "DE 0 A 1.1 LBS"**, en los tres
tarifarios (CER, CEM, CKM).

**No requiere cambio de código: confirma la tolerancia que ya está
implementada.** El `.10` de `TOLERANCIA_LIBRAS` es exactamente ese límite —
todo lo que redondea a 1.0 lb (o sea, por debajo de 1.10) cae en ese escalón y
paga el mínimo de L.200.

El label queda un poco holgado —estrictamente sería "hasta 1.09"— pero su regla
hablada manda y coincide: *"uno punto uno ya es uno y medio"*. La diferencia
práctica entre tolerancia 0.09 y 0.10 es un solo peso: **exactamente 1.10 lb**.
Vale confirmárselo en una línea, pero el audio ya lo resuelve.

⚠️ **La leyenda de colores sigue sin aplicarse.** Tercera versión seguida con
los precios en `theme0` (blanco) y los colores solo en las dos celdas de la
leyenda. Las monedas de los cargos que faltan siguen dependiendo de que él las
cargue por el CRUD (A2-01), que para eso ya está completo.

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

### A2-08 · A los servicios extra les faltaba el mínimo — ✅ **HECHO** (PR-C6.12)

En el sistema viejo el mínimo era **obligatorio** en cada servicio:

> "Precio mínimo a cobrar, lo tiene obligado."

`Tarifa` sí tiene `minimo_monto` / `minimo_moneda`. **`ServicioExtra` no tiene
ningún campo de mínimo** — sus columnas son `codigo, descripcion, costo,
precio_venta, moneda, precio_incluye_isv, position, activo, notas`.

Y hace falta de verdad: el **retornado de Miami** es exactamente eso — *"$5 es
como un precio mínimo que cobramos"*.

El CRUD de `/servicios_extra` ya tenía moneda y el check de ISV; faltaba el
mínimo.

**Arreglo (PR-C6.12):** `minimo_monto` + `minimo_moneda`, con la moneda del
piso **independiente de la del precio** — mismo criterio que `Tarifa`, donde el
flete se cotiza en dólares y el piso vive en Lempiras porque así lo pone la
competencia.

`ServicioExtra#cobro_para` aplica el piso y lo usa la línea automática de la
pre-factura. Un detalle que importa: el mínimo **se compara sin ISV** cuando el
precio lo trae adentro. Yusef habla del mínimo como precio final (los L.200 son
con impuesto); comparar el bruto contra un subtotal neto habría dejado el piso
un 15% más alto de lo que él dijo.

Esto desbloquea que Yusef cargue bien los cargos (A2-01): el **retornado de
Miami** es exactamente un mínimo.

---

### A2-09 · Escalonado — la regla de redondeo — ✅ **ARREGLADO** (PR-C6.2)

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

**Arreglo (PR-C6.2):** `Tarifa::TOLERANCIA_LIBRAS = 9/100`, y el redondeo le
resta la tolerancia antes del ceil. Los `.10` y `.60` son justamente esos
umbrales: la báscula tiembla y no se le cobra media libra a alguien por 30
gramos.

Va con un guard para que un peso menor que la tolerancia no se vuelva
negativo — un peso negativo en una factura es peor que uno mal redondeado.

⚠️ **La tolerancia queda fija en 0.09**, que es la lectura literal del audio.
Yusef describió la regla **solo para incrementos de media libra**; si algún día
crea una tarifa con incremento de 1 lb hay que preguntarle si sigue igual o es
proporcional. Hay un test que **documenta el comportamiento actual** para ese
caso, de modo que cambiarlo sea deliberado y no un efecto colateral. Sigue
como pregunta ALTA en el Excel.

---

### A2-10 · Faltan EXPRESS y CKA en la tabla de escalones — ✅ **CONFIRMADO** (RP-14): los manda antes de lanzar

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

> **Actualizado 2026-08-09** con las respuestas del PDF. Las tachadas quedaron
> cerradas; ver `RP-nn` más abajo para la respuesta literal.

7. ~~**Manejo y gastos de destino** — la hoja dice LPS, el audio sugiere USD~~
   ✅ **L.1 + ISV** (RP-05)
8. **Recolecta** — ¿el $35 de Miami y la tabla por zona son dos cosas distintas?
   ⚠️ **a medias**: el precio quedó (editable, 35/25 según categoría, como
   **mínimo**), pero si Miami y Honduras son uno o dos cargos sigue abierto
   (RP-10)
9. ~~**Retornado de Miami** — ¿$5 mínimo con escalones, o $5 y $15 son dos cargos?~~
   ✅ **dos cargos: $5 y $10** — tachó el 15 (RP-11)
10. ~~**Entrada y salida** — ¿de qué depende que sea $5 o $10?~~
    ✅ **base $5, sube a criterio por tamaño y complejidad** (RP-12)
11. ~~**Flete México** — ¿en qué moneda?~~
    ✅ **$5 por lb o VLb + ISV** (RP-13a)
12. **Etiqueta internacional** — ¿precio y en qué moneda? — **sigue abierta**,
    la dejó en blanco (RP-13b)
13. **Tolerancia del redondeo** — el `.10/.60` es para incrementos de media
    libra. Si crea una tarifa con incremento de 1 lb, ¿la tolerancia sigue
    siendo 0.09 o es proporcional? (A2-09) — **sigue abierta**
14. **Recolecta: el 0 de Personal CEC** — ¿es descuento del 100% o "sin
    definir"? Tiene precios en todo lo demás (A2-13) — **sigue abierta**
15. ~~**Flete México** — el mínimo (6) es mayor que el precio (5)~~
    ✅ **el mínimo era el error: no hay** (RP-13a)
16. ~~**La hoja de precios** — la versión del 7 de agosto es idéntica a la del 5~~
    ✅ superada: la del 8 sí trajo cambios (A2-14)

---

### Audio 2 — cambios que se ocupan

**Urgente**

| ID | Qué |
|---|---|
| ~~A2-04~~ | ~~Cambio de servicio cobraba $15 (≈L.373)~~ ✅ **arreglado** — L.100 exactos |
| ~~A2-09~~ | ~~El redondeo de libras cobra de más en `.01–.09` y `.51–.59`~~ ✅ **arreglado** |

**Nuevo**

| ID | Qué |
|---|---|
| ~~A2-08~~ | ~~Campo de **mínimo** en `ServicioExtra`~~ ✅ **hecho** |
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

## Conversación 6 · Respuestas al PDF de preguntas (recibidas 2026-08-09)

Yusef devolvió el PDF de 23 preguntas (`docs/entregables/preguntas_para_yusef.pdf`)
contestado a mano. Llegaron fotos de **las páginas 1 a 4**, o sea `P1`–`P16`.
Jorge confirmó que **sí contestó P17–P23**, pero esas fotos todavía no llegan.

Los ids son `RP-nn`, donde el número **es el de la pregunta en el PDF** —
trazabilidad 1:1 contra `lib/tasks/docs.rake:1132-1298`. Prefijo distinto de
`A1-`/`A2-` a propósito: son respuestas a un artefacto nuestro, no items
extraídos de un audio.

Cada item lleva la **transcripción literal** de lo que marcó o escribió, después
la lectura, y al final el veredicto.

---

### RP-01 · Un Cliente Amigo puede pagar MÁS que el público — **SIGUE ABIERTA**

Ninguna casilla marcada. Al margen, con una flecha al párrafo:

> "ACTIVA Los Precios del Escalonado"

**Lectura.** La intención es clara: las categorías también van escalonadas. Lo
que **no** dice es qué se le cobra a un Cliente Amigo **mientras** esas tablas
no lleguen — y en RP-14 él mismo dice que las de CKA y EXPRESS las manda
"antes de lanzar sistema". Hoy un Cliente Amigo con 200 lb de CER paga $840 y
uno de la calle paga $700.

Va a la ronda 2 con la pregunta acotada: ¿precio fijo de la categoría, o el
menor de los dos, hasta que lleguen las tablas?

---

### RP-02 · Mayoristas: solo vino un precio — **SIGUE ABIERTA**

Ninguna casilla marcada. Escribió:

> "Por que Usamos tarifas Diferentes Para Clientes / tarifario Único."

**Lectura.** No se lee como decisión. Puede querer decir "usamos tarifas
distintas por cliente, no un tarifario único" o exactamente lo contrario. De
Mayoristas solo llegó CKM a $1.50; CER, CEM, CKA y EXPRESS vinieron en cero, y
así no se les puede facturar esos servicios. Se pregunta de nuevo, concreto.

---

### RP-03 · ¿Prendemos el redondeo a media libra? — ✅ **CERRADA**

Marcó:

> ☒ **Préndanlo ya.**

Y **no** marcó "primero quiero ver el número calculado con mis paquetes reales".

**Consecuencia.** Es la autorización que el informe de impacto iba a pedir. Eso
re-ordena el plan del escalonado: el informe deja de ser compuerta y pasa a ser
verificación posterior. Lo que **no** cambia es que el bug de frontera
(`PR-C6.18`) tiene que aterrizar **antes** de que alguien pulse el botón —
activar es exactamente lo que lo despierta.

---

### RP-04 · ¿Dónde aplica el redondeo? — ✅ **CERRADA**

Marcó:

> ☒ También en las tarifas por categoría: Clientes Amigos, Shein, Personal CEC
> y las demás.

Y escribió al lado: **"Todo"**.

**Consecuencia.** El botón de activación no necesita selector de alcance: pone
`incremento_libras` en todas las filas del servicio, lista y categorías.

---

### RP-04b · Cobro por volumen editable por cliente y por servicio — ✅ **CERRADA** (A4-01) e implementada

En la misma página, suelto abajo, no como respuesta a nada:

> "Formas de cobro
>  Hay Clientes Que solo se les cobra Volumen en ciertos servicio
>  (necesita quedar Editable por Kliente y Por servicio)"

**Lectura.** Hoy el peso a cobrar es `max(peso real, peso volumétrico)`
(`VolumetricoCalculator#peso_a_cobrar`). Esto pide poder forzar **siempre
volumen** para ciertos clientes en ciertos servicios, aunque el peso real sea
mayor.

**IMPLEMENTADO en PR-C6.41** (ver `A4-01`, que es donde el audio 4 lo cerró).

- Tabla `cliente_cobro_volumetricos` — **la fila es el flag**: si existe
  `(cliente, tipo_envio)`, ese cliente paga solo volumétrico en ese servicio.
- Se configura en la ficha del cliente, tarjeta **"Cómo se le cobra"**, donde
  Yusef dijo: *"cuando creamos el cliente"*.
- `VolumetricoCalculator.entre_peso_y_vlbs` pasa a ser el único lugar donde se
  decide qué peso manda; `Paquete` y `CotizadorFlete` lo llaman a él (antes eran
  dos copias sueltas del `max`).
- **El mínimo del servicio se sigue aplicando** — decisión de Jorge: es una regla
  del servicio, no del peso. Vive aguas abajo en `Tarifa#cobro_para` y este PR
  no lo toca.
- **Guard de cero**: sin medidas el volumétrico es 0, y ahí se cobra el peso
  real. Es el único camino por el que la feature podría regalar flete.
- **Nadie arranca con el flag puesto.** Prenderlo baja lo que se le cobra a ese
  cliente, así que queda auditado con `paper_trail` en el join.

---

### RP-05 · Manejo y gastos de destino: ¿lempiras o dólares? — ✅ **CERRADA**

Marcó:

> ☒ Va como dice la hoja: **L.1 + ISV**.

Cierra la pregunta 7 del registro del audio 2, donde la hoja y el audio se
contradecían.

---

### RP-06 · CKM: ¿precio fijo o por libra? — ✅ **CERRADA**

Sobre la opción "L.200 con ISV incluido, pese lo que pese" escribió una flecha
y:

> "Es EL **Mínimo**"

Y debajo, abarcando las dos opciones con una llave:

> "Después es el **Escalonado**"

**Lectura.** L.200 es el piso; pasado ese piso manda la tabla escalonada. Es el
mismo mecanismo que ya tiene CER — **no hace falta código nuevo**.

---

### RP-07 · Mínimo en libras del marítimo (CEM y CKM) — ✅ **CERRADA**

Ninguna casilla. Escribió:

> "**MANDA el Escalonado**"

**Lectura.** No hay mínimo en libras: el escalonado decide. Cierra la duda
vieja de "8/20 lb vs 3 o 4 lb".

**Ya se cumple**: `minimo_libras` viene nil en todas las tarifas sembradas y
`tarifa.rb` solo lo aplicaría si existiera. Solo hace falta verificarlo en
staging — no se toca código.

---

### RP-08 · Confirmación: ¿el mínimo de CER es L.200 parejo? — ✅ **CERRADA** (y confirma el motor)

Marcó **"No, es así:"** y escribió la aritmética:

```
tasa 27.10
4.50 × 1   = 121.95  + ISV = 200      "ya con ISV"
4.50 × 1.5 = 182.93  + ISV = 210.36   "ya con ISV"
             ↓ libras
```

**Lectura, y es la más importante de todo el PDF.** Esa cuenta **confirma que
el motor de mínimos está bien**: el sistema guarda el mínimo **neto de ISV**
(CER: `minimo_monto = 173.91 LPS`) y le suma el ISV al final, que es
exactamente lo que él hizo a mano.

- 1 lb → $4.50 < $6.42 (=173.91/27.10) → aplica el mínimo → 173.91 × 1.15 = **L.200** ✓
- 1.5 lb → $6.75 > $6.42 → 6.75 × 27.10 = 182.93 → × 1.15 = **L.210.37**

Él escribió **210.36**. El centavo de diferencia es de orden de redondeo: aplicó
el ISV sobre `182.925` sin redondear, y el motor redondea el subtotal a dos
decimales antes de convertir. No se cambia sin que él lo pida.

**Y destapó la tasa.** El sistema tenía **24.85** sembrada. Con esa, la segunda
línea **no reproduce**: 6.75 × 24.85 = L.167.76, debajo del mínimo neto, así que
el paquete caía en L.200 y no en L.210.37. Jorge decidió fijarla en **27.10**
(`PR-C6.29`), que además creó la pantalla para que un admin la maneje — hasta
ese PR la tasa solo se podía cambiar con un deploy.

---

### RP-09 · ¿Qué hacemos con Regular y VIP? — **ABIERTA A MEDIAS** (ver A4-05)

Ninguna casilla. Con una flecha al título:

> "→ categorías Actuales del Excel"

**Lectura.** Se entiende que Regular y VIP son lo viejo, pero no dice a qué
categoría pasan los 8 clientes que hoy están ahí. Sin eso no se pueden migrar.

> **Actualización (audio 4).** En el audio dice *"esas categorías ya no van,
> ahora es el escalonado"* — o sea que **se eliminan**. Lo que falta es solo el
> destino de los 8 clientes. Ver `A4-05`; sale del audio, así que va *a
> confirmar* y no se migra nada sobre esa base.

---

### RP-10 · Recolecta — **(a) CERRADA con matiz · (b) SIGUE ABIERTA**

Una llave abarcando las opciones de precio, y al lado:

> "Editable.
>  $35 o $25 Dependiendo de la categoría de Precio de cliente
>  **es el mínimo a cobrar**."

**(a) El precio — cerrada con matiz.** No es tabla por zona ni precio parejo:
es **editable**, y el 35/25 según la categoría del cliente es el **piso**, no
el precio final. Eso **contradice** lo documentado en su momento como "tabla de
tarifas por zona".

**Ojo, es modelado nuevo**: `ServicioExtra` tiene un `minimo_monto` **plano**,
no uno por categoría de precio. No es carga de datos.

**(b) ¿La recolecta de Miami y la de Honduras son dos cobros distintos?** —
**quedó sin marcar**. Y bloquea (a): sin saber si son uno o dos cargos no se
sabe cuántos mínimos hay que modelar.

---

### RP-11 · Retornado de Miami: ¿uno o dos cargos? — ✅ **CERRADA**

Marcó la segunda opción y **tachó el 15**:

> ☒ Son dos cargos separados: Retornado ($5) y Retornado USPS ($~~15~~ **10**).

Al margen:

> "5 + 10 Retorno. **Hay que llevarlo a sucursal**"

**Lectura.** Dos cargos, $5 y $10 USD. La nota del margen es contexto operativo:
el retorno implica llevar el paquete a una sucursal.

---

### RP-12 · Entrada y salida (IN & OUT): ¿de qué depende? — ✅ **CERRADA**

Sin marcar casilla, escribió sobre las dos:

> "**$5 Paquete pequeño** → sube a consideración de tamaño complejidad"

**Lectura.** Base $5 para paquete pequeño, y de ahí sube **a criterio**, según
tamaño y complejidad. O sea: no es automático — se cobra $5 y se ajusta a mano
cuando corresponde.

---

### RP-13 · Flete México y etiqueta internacional — **(a) CERRADA · (b) SIGUE ABIERTA**

Al título, con flecha:

> "→ Precio x Lbs o VLbs"

**(a) Flete México — cerrada.** En "Los buenos son: precio $___ · mínimo $___"
escribió **5** en el precio, **tachó el mínimo**, y agregó **"+ ISV."**

O sea: **$5 por libra o libra volumétrica, más ISV, sin mínimo**. El "mínimo 6
mayor que el precio 5" de la hoja era el error, y así se cierran de una las dos
preguntas viejas sobre este cargo.

**(b) Etiqueta internacional — abierta.** Quedó **en blanco**. Sigue sin precio
y sin moneda, así que no se puede dar de alta como servicio.

---

### RP-14 · ¿CKA y EXPRESS también llevan escalonado? — ✅ **CERRADA**

Marcó:

> ☒ Sí llevan — les mando las tablas.

Al margen:

> "Si en el Futuro **Antes de Lanzar Sistema**"

**Lectura.** Sí llevan, y las tablas llegan antes del lanzamiento. Cuando
lleguen es **carga por CRUD** — la hace su equipo, no es un PR.

---

### RP-15 · La leyenda de colores / la moneda de cada cargo — **PENDIENTE DE OFICINA**

Ninguna casilla. Escribió:

> "Expres y CKA
>  Lo llenaremos Después **los de Oficina**"

**Lectura.** Delegado a su equipo administrativo, sin fecha. La leyenda de
colores de la hoja de precios —la que dice en qué moneda va cada precio— sigue
sin aplicarse a las celdas.

---

### RP-16 · Visto bueno final a los precios cargados — **SIGUE ABIERTA**

Escribió:

> "**No Ha Revisado**"

**Lectura.** La hoja 2 del Excel —el detalle completo de lo que el sistema va a
cobrar— sigue sin revisar. Se le vuelve a mandar junto con el informe de
impacto del redondeo, para que revise las dos de un solo.

---

### RP-17 … RP-22 — ✅ **CONTESTADAS** (fotos recibidas el 2026-08-10)

Llegaron las páginas 6/7 y 7/7. Las respuestas literales y su lectura están
abajo, en la sección del **audio 4**. Resumen:

| Id | Cómo quedó |
|---|---|
| RP-17 | ✅ escribió el formato con mes: `R` + sucursal + año + mes + correlativo |
| RP-18 | ✅ se puede bajar la cantidad de cajas, **con PIN de supervisor** |
| RP-19 | ✅ el origen **entra en el cobro** — corrige `PR-C6.38` |
| RP-20 | ⏳ sin marcar — pero **la deuda ya se pagó**: las tres existen (`PR-275`) |
| RP-21 | ✅ los cuatro roles llevan PIN — son los mismos `ROLES_AUTORIZANTES` |
| RP-22 | ⏳ "llenaremos en oficina" |

**RP-21 no bloquea código.** Los cuatro que marcó ya eran los del sistema; lo
que falta son los **nombres**, y eso lo carga el admin desde el CRUD de usuarios.
Lo mismo con el PIN de Julien para `PR-C6.28`: el flujo está listo y el banner
avisa solo mientras nadie tenga PIN asignado.

---

### RP-23 · La etiqueta impresa — ⏳ **PENDIENTE** (escribió "Pendiente")

> ⚠️ **Corrección.** Acá decía "cerrada de facto" porque mandó la etiqueta
> anotada en rojo. Esa foto resolvió la **maquetación** (`PR-C6.27`), pero la
> pregunta 23 pide otra cosa: **imprimir una y probar que el lector agarre el
> código de barras**. En la página 7 escribió "Pendiente". Y ahora conviene
> que la imprima **después** de aplicar `RP-17`, porque el número cambia y va
> justo en el código de barras.
>
> ✅ **Ya se puede (2026-08-11).** `RP-17` salió en `PR-C6.40` (merge #259): el
> número de recepción ya lleva sucursal, año y mes. La prueba deja de estar
> bloqueada. Y en el audio 4 él dijo *"eso lo puedo hacer yo… queda pendiente,
> pendiente tuyo"*, así que la corre él.

No la contestó por escrito: **mandó la etiqueta impresa anotada en rojo**, que
resolvió la maquetación. Se documenta abajo, en su propia sección.

---

### Lo que el PDF cerró

| Pregunta vieja | Cómo quedó |
|---|---|
| Manejo y gastos de destino: ¿LPS o USD? | ✅ L.1 + ISV (RP-05) |
| Retornado: ¿uno o dos cargos? | ✅ dos: $5 y $10 (RP-11) |
| Entrada y salida: ¿de qué depende? | ✅ base $5, ajuste manual (RP-12) |
| Flete México: ¿moneda? ¿mínimo mayor que el precio? | ✅ $5/lb o VLb + ISV, sin mínimo (RP-13a) |
| Mínimo en libras del marítimo (8/20 vs 3-4) | ✅ no hay: manda el escalonado (RP-07) |
| CKM: ¿fijo o por libra? | ✅ L.200 es el mínimo, después escalonado (RP-06) |
| ¿Prendemos el redondeo? | ✅ "préndanlo ya" (RP-03) |
| ¿Dónde aplica el redondeo? | ✅ "todo" (RP-04) |
| ¿CKA y EXPRESS llevan escalonado? | ✅ sí, tablas antes de lanzar (RP-14) |
| ¿El mínimo de CER es L.200 parejo? | ✅ confirmado el motor, y destapó la tasa (RP-08) |

### Las que siguen vivas

> Esta tabla se leyó como el estado real y **estaba vieja**: el audio 4 y las
> páginas 6-7 cerraron varias y nadie bajó el resultado hasta acá. Reconciliada
> el 2026-08-11 contra las secciones `A4-*` y `RP-17`…`RP-23`.

| Id | Qué falta | Novedad |
|---|---|---|
| RP-01 | Qué se cobra a las categorías mientras no lleguen sus tablas escalonadas | — |
| RP-02 | Mayoristas: qué se les cobra en CER/CEM/CKA/EXPRESS | — |
| RP-09 | **Solo** a qué categoría pasan los 8 clientes | El audio dice que Regular y VIP **se eliminan** (`A4-05`, *a confirmar*) |
| RP-10b | ¿La recolecta de Miami y la de Honduras son uno o dos cargos? | El audio no la contesta; sí agrega que la tarifa la crea un supervisor (`A4-06`) |
| RP-13b | Etiqueta internacional: precio y moneda | Salió en el audio pero el transcript no se entiende (`A4-07`) |
| RP-15 | La leyenda de colores/moneda de la hoja (lo hace su oficina) | — |
| RP-16 | El visto bueno a la hoja 2 del Excel | Falta la tabla de EXPRESS: *"llenaremos después"* |
| RP-20 | Que **elija** una de las tres | Ya no es deuda nuestra: las tres existen y se pueden oír (`PR-275`) |
| RP-22 | Los proveedores de Entrega Personal | Escribió *"llenaremos en oficina"* |
| RP-23 | Imprimir una etiqueta y probar el lector — **él dijo que lo hace él** | **Desbloqueada**: esperaba a `RP-17`, que salió en `PR-C6.40` |
| — | Tolerancia del redondeo con incremento de 1 lb (viene del audio 2) | — |
| — | El 0 de Personal CEC en recolecta: ¿descuento del 100% o sin definir? | — |
| — | Motivos de retención, notas predeterminadas y grabaciones de voz | Los tres pendientes que el papel le listaba; siguen sin llegar |

### Las que ya cerraron y esta tabla no reflejaba

| Id | Cómo cerró |
|---|---|
| RP-04b | ✅ **Contestada** en `A4-01` (por cliente y por servicio) e **implementada** en `PR-C6.41` |
| RP-17 | ✅ El número de recepción lleva sucursal, año y mes — `PR-C6.40` |
| RP-18 | ✅ Se puede bajar la cantidad de cajas, con PIN de supervisor |
| RP-19 | ✅ El origen entra en el cobro — corrige `PR-C6.38` |
| RP-21 | ✅ Los cuatro roles llevan PIN; falta asignar los PIN desde el CRUD, no es decisión |

### Las que nacen

| Id | Qué |
|---|---|
| — | La tasa: quién la mantiene y cada cuánto (aviso, no pregunta — ya se fijó en 27.10) |

### Las que están escritas pero viven **solo en código**

Estas nunca entraron a este documento porque nacieron dentro de un entregable, y
por eso preguntar *"¿qué está pendiente?"* leyendo solo este archivo daba una
lista incompleta. Se anotan acá; las respuestas, cuando lleguen, se documentan
como todas las demás.

| Id | Qué pregunta | Dónde vive |
|---|---|---|
| RP-24 | EXPRESS: ¿la libra vale $8.00 (hoja de abril) o $7.50 (sistema)? | `lib/servicios_pdf.rb` |
| RP-25 | EXPRESS: ¿el mínimo es $14.95 con ISV o $10.00 más ISV? | idem |
| RP-26 | CEM: el mínimo de 8 libras no se aplica — ¿manda el dinero o las libras? | idem |
| RP-27 | CKM: ¿la libra vale $1.50 (hoja) o $1.90 (sistema)? | idem |
| RP-28 | CKM: dos reglas del mismo audio se contradicen — ¿dinero o libras? | idem |
| ~~RP-29~~ | ~~El redondeo escalonado sobre el peso de báscula está apagado — ¿se prende?~~ **✅ CERRADA POR DUPLICADA**: ya la había contestado en `RP-03` ("préndanlo ya") y `RP-04` ("todo") el 2026-08-09. El PDF se armó leyendo el estado del código sin cruzarlo contra sus respuestas. El redondeo quedó puesto en `PR-C7.10` | idem |
| ~~RP-30~~ | ~~Aduana y bodega: hoy el estado se cambia a mano — ¿hace falta pantalla?~~ **✅ CERRADA en la Conversación 7**: sí hace falta, y es el escaneo del manifiesto (`A7-03`…`A7-05`). De paso corrigió el orden del diagrama (`A7-01`) | `lib/procesos_pdf.rb` |

**`RP-24`…`RP-29` son plata.** Cada una es una diferencia entre la hoja de abril
y lo que el sistema cobra hoy: mientras no se contesten, alguna de las dos está
cobrando mal. Salen en `docs:servicios_pdf`.

**`RP-30`** salía en `docs:procesos_pdf` y **la contestó la Conversación 7**: el
estado no se cambia a mano, se cambia escaneando el manifiesto. El documento
deliberadamente **no** pregunta por empaque, entregas, manifiestos ni caja: hasta
terminar etiquetas y entrega personal no se le ponen enfrente (Jorge,
2026-08-11) — y Yusef lo ratificó por su cuenta en `A7-34`. Las preguntas nuevas
arrancan en `RP-31`.

---

## Conversación 6 · Audio 3 (2026-08-08) — pre-alertas, escaneo y sucursal de retiro

Tercer audio de la **misma reunión** del 2026-08-08: Yusef siguió probando el
sistema en vivo, esta vez con la pistola de códigos de barras y paquetes
reales de los cuatro carriers. Ids `A3-nn`, continuando la serie de audios.

---

### A3-01 · Falta el estatus por tracking en `/pre_alertas/edit` — ✅ **PLANIFICADO** (PR-C6.25)

> "Acá no me sale todavía el estatus, mira. ¿Te acordás que **aquí debería ir
>  el estatus**? Si ya fue recibido, si está en estado prealerta, etcétera."

En `show.html.erb` sí sale (badge con `pap.paquete.estado`); en `edit.html.erb`
no existe la columna.

---

### A3-02 · La columna "Vinculado" repite el tracking — ✅ **DIAGNOSTICADO** (PR-C6.25)

> "Ahora este **vinculado** es el que no… no entiendo. Yo creo que este ha de
>  ser la recepción, ¿o no? Si es para poder unirlos. No, porque **este es el
>  mismo que este**."
> "Revisá bien ahí y me dejás saber."

**Tenía razón.** La columna usa `paquete_display_id`, que es
`numero_recepcion.presence || tracking`. Como `crear_paquete_esperado` crea el
paquete esperado **sin** número de recepción, el link muestra el tracking otra
vez — la misma columna dos veces.

---

### A3-03 · Tras etiquetar el estado debe ser **recibido**, no empacado — ✅ **ARREGLADO** (PR-C6.22)

> "**Empacado dice, y empacado no es lo que sigue**… queda aquí en recibido,
>  porque apenas se recibió y se tiene ahí. Cuando hagamos lo que hablamos del
>  empaque, ahí sí va a decir empacado, porque ya lo escaneamos, lo agregamos y
>  lo metimos."

Jorge lo había notado esa mañana sin saber qué era: *"yo lo noté ahorita en la
mañana, pero no sabía que estaba con él"*.

`ESTADOS_ORDEN` es `recibido_miami → empacado → …`, así que el paquete nacía un
escalón adelantado: el dashboard contaba como empacado lo que sigue en la mesa,
y `fecha_empacado` guardaba la hora de un paso que nadie dio.

---

### A3-04 · Cambio de servicio "envía donde no es" — ✅ **ARREGLADO** (PR-C6.23)

> "Cambio de servicio **envía donde no es**."
> "Para mí que si hacemos cambio de servicio nada más al producto, nos tire de
>  un solo a esta ventana. Si yo presiono cambio de servicio, **me tire aquí de
>  un solo a esto**."
> "Es que **ellos no manejan la página de paquetes**."

**La mitad ya estaba resuelta**: marcar el check a mano abre el modal al
instante, sin ida al servidor. El bug era el botón "Cambio de servicio" del
modal de **duplicado**, que navegaba a `/paquetes/:id?mode=edit`.

Es la misma queja que ya había hecho por la **otra** opción de ese mismo modal
(*"me mandaste a editar y yo no quiero editar mi paquete"*, A1-07 / PR-C6.10).
Quedó a medias: se arregló una de las dos.

---

### A3-05 · "Enter no lo encontró… tiene que ser rápido" — ✅ **ARREGLADO** (PR-C6.21)

> "Le di enter y **no lo reconoce**."
> "Ahora sí, cuando le di **tap** ya reconoció."
> "**Le di enter rápido y mete rápido**, aquí es donde tenés que ver cómo
>  integrar eso."
> "Tiene que ser **rápido**."

Dos causas distintas, las dos reales:

1. **La búsqueda** era `where(tracking: valor)` — exacto y case-sensitive sobre
   una sola columna (ver A3-08 y A3-09).
2. **Una carrera en el navegador**: el `fetch` salía sin cancelar el anterior y
   su `.then` nunca verificaba que el campo siguiera diciendo lo mismo. La
   pistola manda Enter sola, así que escanear A y enseguida B dejaba **el
   cliente de A auto-rellenado sobre el paquete de B**. Eso se factura mal.

El arreglo **no** es un debounce: sería justo lo contrario de lo que pidió.

---

### A3-06 · Quitar el cobro de cambio de servicio, con permiso — **PLANIFICADO** (PR-C6.28)

> "Aquí es donde hay un dilema: si el muchacho mío se equivocó y lo está
>  cambiando, tenemos que buscar una manera de **poderle quitar ese cambio de
>  servicio**. Eso sería como que le digan al **supervisor** de ellos allá en
>  Miami: 'hey, mire, yo me equivoqué, lo ingresé mal y era otro tipo de
>  envío', y entonces él lo pueda eliminar el cobro."
> "No estamos hablando de Jordan o Julio, sino que él se llama **Julien**, el
>  supervisor… que él sí pueda eliminarlo **con el usuario de él**."
> "Que tenga algo aquí en algún lado, **acá cerca**, que diga que **se le está
>  cobrando** cambio de servicio, y lo vamos a eliminar."

**Trampa encontrada.** El cobro nace en **dos lugares**: la línea automática de
la pre-factura y una **NotaDebito aparte** dentro de `facturar!`. La vía que ya
existe (autorización con PIN → borrar la línea) **no suprime la NotaDebito**.
Por eso el diseño es apagar el flag `solicito_cambio_servicio`, que suprime las
dos.

**No depende de código.** `RP-21` cerró los roles; lo único que falta es que el
admin le asigne PIN a Julien desde el CRUD de usuarios. Mientras nadie lo tenga,
el banner lo dice en vez de ofrecer un botón muerto.

---

### A3-07 · Empacar por sucursal — **el módulo de empaque queda DIFERIDO**

> "Se me olvidó decirte algo… lo que queremos es **empacar todas las sucursales
>  en Miami por separado, en caja por separado**. Si dice Tegucigalpa, es
>  sucursal — o sea, sucursales ajenas a San Pedro."
> "Hay dos áreas donde yo creo que se ocupa: una en **etiquetar** y dos en
>  **empacar**."
> "El de empacar **no sé si lo cargamos ahorita** y después lo vamos a mejorar,
>  porque pueda que sea complicado hacer tanto de un solo."

Lo que sí quiere ya, en etiquetar:

> "Al mismo instante que les aparezca… que el sistema les diga **sucursal tal**."
> "Yo opino dos cosas: una es que le salga **en rojo** 'sucursal Tegucigalpa' o
>  'se entregará en Tegucigalpa' — solo que les diga que eso es de Tegucigalpa."
> "Solo quiero **un modal al principio y uno al final**."

Y la distinción que remarcó dos veces:

> "Recordá que **la ciudad donde es la persona no es el mismo lugar donde se le
>  entrega**. La idea es ponerle dónde el hombre va a querer su retiro."

O sea: es la **sucursal de retiro**, que ya existe y ya se imprime en la
etiqueta (`RETIRA EN …`). **No se agranda el alcance** — el módulo de empaque
lo difirió él.

Contexto físico que dio: en Miami hay tres estaciones de etiquetado más una en
la oficina, y bolsas de Amazon para lo no digitado y lo ya etiquetado. Lo que
pide es una **tercera bolsa por sucursal**.

---

### A3-08 · El escaneo de USPS trae más de lo que el cliente pre-alertó — ✅ **ARREGLADO** (PR-C6.21)

Probó los cuatro carriers con la pistola. Sobre USPS:

> "El tracking de USPS **solo es desde donde dice 92**."
> "**Esto es lo que el cliente recibe de tracking y esto es lo que le escanea
>  el sistema.**"

La etiqueta lleva el código completo (`420` + ZIP + servicio + tracking) y el
cliente pre-alerta solo la cola. Con match exacto, ese escaneo no encontraba
nada: ni el paquete esperado ni su pre-alerta, y Miami grababa un paquete nuevo
al lado.

El arreglo acepta que lo guardado sea **sufijo** de lo escaneado, con piso de
longitud a los dos lados, **sin hardcodear el 92** — así cubre igual UPS y
FedEx.

---

### A3-09 · Buscar también por el tracking secundario — ✅ **ARREGLADO** (PR-C6.21)

> "Ahora el sistema debe buscar en esto también, debe buscar en la base, y
>  **eso no estaba**."

Tenía razón: `Paquete.buscar` sí cubría el secundario, pero `check_tracking`
—el endpoint que usa la pistola— no lo usaba. Matiza **A1-26**, que daba el
secundario por resuelto: el *display* estaba, la **búsqueda** no.

---

### A3-10 · Pre-alerta admin: autofill, dropdowns y duplicados — **PLANIFICADO** (PR-C6.25 / PR-C6.26)

De la página de notas y del audio:

> "/pre-alertas/new pero rol Admin → **abre tarjetas de crédito en tracking**"
> "**Preseleccionar** de los dropdown."
> "Mira, ve, cómo le di enter: ya tiene un error y **no lo detecta que ya
>  existe**."
> "Aquí esto **no tiene sentido** porque es consolidado… los servicios son como
>  si repaque aquí."

Verificado en el código:

- Los inputs de tracking del admin **no tienen** `autocomplete`, `inputmode` ni
  nada anti-autofill; el portal cliente sí tiene un Stimulus que sanea. De ahí
  el autofill de tarjetas.
- El único dropdown que arranca vacío es **Tipo de Envío** (`include_blank`),
  aunque el modelo backfillea CER al guardar: el default existe pero **no se
  ve**. Cliente y Proveedor son texto libre, no dropdowns.
- **No hay detección de duplicado**: la unicidad de tracking está scopeada a
  `pre_alerta_id`, y `Paquete` no tiene unicidad de tracking. Además
  `edit.html.erb` **no tiene bloque de errores**, así que un 422 se re-renderiza
  mudo.
- Los campos que "no tienen sentido" — **no dijo cuáles**. Se le pregunta antes
  de tocar nada.

---

### A3-11 · Aprobados en vivo — **no se tocan**

- **Motivos de retención editables** (A1-18): *"aquí le hiciste un cuadro ahí
  atrás, y todas ahí en motivos de retención. Ah, sí, está perfecto eso. Esa es
  la idea de lo que queremos: un montón de cosas que nosotros podamos cambiar,
  porque este es bien cambiante el negocio."* Falta que mande la lista.
- **El cuadrito de descripción de Miami**: aprobado.
- **Las iniciales de usuario**: confirmó que las define el admin —
  *"nosotros creamos nuestras propias iniciales"*, *"el sobrenombre es lo que
  realmente va"*.

---

### A3-12 · Fuera de alcance

El servidor de Render, la caché y el precio del hosting ocuparon un buen rato
del audio. No es trabajo de sistema; queda anotado para que no se busque
después como si fuera un requerimiento.

---

## Conversación 6 · La etiqueta anotada y la página de notas (2026-08-09)

### La etiqueta impresa, anotada en rojo

Yusef imprimió una etiqueta real y le dibujó recuadros encima. La etiqueta
salió así:

```
[código de barras]
RS0002026000001
9621091390000806743500382574 95791...      ← cortado
ROBERTO HERNANDEZ
CEC-005   08-Aug-2026 16:49   1/1  FRA · Tegucigalpa  Reg: A
RETIRA EN TEGUCIGALPA                             CER
```

Anotaciones:

| Anotación | Apunta a |
|---|---|
| **LOS TRACKING DEBEN CABER COMPLETOS** | regla general, arriba de todo |
| **TRACKING PRIMARIO** | recuadro sobre `RS0002026000001` |
| **TRACKING SECUNDARIO** | recuadro **debajo**, o sea en línea propia |
| **CLIENTE TERCERO** | recuadro con dos líneas a la zona del nombre |
| **FECHA Y HORA** | recuadro sobre `08-Aug-2026 16:49` |

**Ojo con el vocabulario.** Él llama "tracking primario" al **número de
recepción** de CEC y "tracking secundario" a los del carrier. No es la
nomenclatura del sistema, pero lo que pide es claro: cada uno en su lugar y
completo.

**El hallazgo.** No faltaban campos — la etiqueta ya imprimía los cuatro. El
`...` era **CSS**: `.t` lleva `text-overflow: ellipsis` y tracking y secundario
iban **concatenados con `" · "` dentro de un solo elemento**, así que lo que se
recortaba era siempre el final del segundo.

Arreglado en `PR-C6.27`: líneas propias, sin recorte, y los escalones de letra
bajaron para hacerle lugar a la línea de más. El tamaño 2.25 × 1.25 in **no se
toca**, como pidió en su momento.

### La página de notas a mano

Escrita durante la misma reunión:

```
Pre-alerta
→ Revisar Vinculado
→ Etiquetar → Recibido miami
→ Cambio de servicio envía donde no es.
→ Cambio de servicio que mande al modal.
→ Enter no lo encontró
   ↳ Tracking → Enter.   ↳ tiene que ser Rápido
/pre-alertas/new pero rol Admin
→ abre tarjetas de crédito en tracking
→ preseleccionar de los dropdown.
```

**El cruce.** Los 8 apuntes caen todos dentro de `A3-01` … `A3-10`. **No hay
items nuevos** y no contradicen nada del audio — igual que pasó con las tres
páginas de la conversación anterior.

---

### Lo que salió del código y no estaba en ninguna lista

Dos cosas que aparecieron al implementar y que nadie había reportado:

1. **El botón "Guardar (F8)" de `/pre_alertas/edit` no hace nada.** La vista no
   setea `autosave-url-value` y el Stimulus corta en seco. Borrar una fila
   tampoco persiste. Va en `PR-C6.25`.
2. **El audit log nunca registró quién.** La guarda
   `respond_to?(:set_paper_trail_whodunnit)` de `ApplicationController` daba
   `false` siempre —el método viene `protected` y `respond_to?` sin el flag los
   oculta—, así que el hook nunca corrió y las versiones de los 41 modelos
   quedaron con `whodunnit` nil. En pantalla se leía "Sistema", que es lo mismo
   que muestra un cambio hecho por un job, y por eso nadie lo notó. Arreglado en
   `PR-C6.30`.

---

### Conversación 6 — cambios que se ocupan

**Arreglado**

| ID | Qué | PR |
|---|---|---|
| A3-05 / A3-08 / A3-09 | El escaneo no encontraba el paquete, y las respuestas se pisaban entre bultos | C6.21 |
| A3-03 | Etiquetar dejaba el paquete en `empacado` | C6.22 |
| A3-04 | Cambio de servicio mandaba a `/paquetes` | C6.23 |
| RP-23 | Los trackings salían cortados en la etiqueta | C6.27 |
| — | El escalón se elegía con el peso crudo y el precio se aplicaba al redondeado | C6.18 |
| RP-08 | La tasa estaba en 24.85; sus cuentas usan 27.10 | C6.29 |
| — | El audit log no registraba quién | C6.30 |

**Planificado**

| ID | Qué | PR |
|---|---|---|
| A3-07 | Aviso de sucursal de retiro en /etiquetar (el empaque queda diferido) | C6.24 |
| A3-01 / A3-02 | Estatus y columna "Vinculado" en pre-alerta admin, más el F8 muerto | C6.25 |
| A3-10 | Autofill de tarjetas, dropdowns y aviso de duplicado | C6.26 |
| A3-06 | Quitar el cobro de cambio de servicio con PIN de Miami | C6.28 |
| RP-03 / RP-04 | Botón para activar el redondeo a media libra | C6.20 |
| RP-16 | Informe de impacto del redondeo, para que revise la hoja 2 | C6.19 |

**Bloqueado por una respuesta**

| Qué | Espera |
|---|---|
| Mínimo 35/25 por categoría en recolecta | RP-10b |
| Etiqueta internacional como servicio | RP-13b |
| Tarifas escalonadas por categoría y de CKA/EXPRESS | RP-01 / RP-14 (las manda él; es carga por CRUD) |

---

## Conversación 6 · Audio 4 y páginas 6-7 — el cuestionario cerrado (2026-08-10)

Llegaron las dos piezas que faltaban: el **transcript del audio del 2026-08-08**
(29 min, Yusef contestando el cuestionario en voz alta mientras Jorge lo iba
leyendo) y las **fotos de las páginas 6/7 y 7/7** con sus respuestas a mano.

Con eso el cuestionario queda **completo**: las 23 preguntas.

> ⚠️ **Sobre el transcript.** Está hecho con `faster-whisper tiny` y se nota:
> frases partidas, palabras inventadas, números mal oídos. **Las fotos mandan.**
> Donde el papel es claro se toma el papel; lo que sale **solo** del audio va
> marcado *a confirmar* y **no se codifica** sobre esa base sola.

---

### A4-01 · El cobro por volumen se configura al crear el cliente — ✅ **cierra RP-04b**

Es lo primero que dice el audio, y contesta la nota suelta que él había escrito
al margen del PDF:

> "Clientes que son **mayoristas o clientes grandes**, que en cierto… y en
>  cierto tipo de envío **solo se les cobra volumen, no peso**. Entonces ahí es
>  donde nosotros necesitamos esa opción."
> "Es lo que le creamos al cliente, **cuando creamos el cliente**… que en este
>  cliente, en estos tipos de envío, va a tener una opción para **seleccionar
>  varios tipos de envío y en cuál sí y en cuál no**."

Y el papel lo respalda: *"necesita quedar editable **por Kliente y por
servicio**"*.

**Lectura.** No es un flag global: es una configuración **por cliente y por tipo
de envío**, que se pone en la ficha del cliente. Hoy el peso a cobrar es siempre
`max(peso real, volumétrico)`; esto pide poder forzar **solo volumétrico** para
ciertos clientes en ciertos servicios.

`RP-04b` deja de estar SIN DEFINIR.

**IMPLEMENTADO en PR-C6.41.** Jorge cerró las tres cosas que quedaban abiertas:
es el **peso volumétrico** (no otra medida), va en la **ficha del cliente** con
tarjeta propia, y **el mínimo del servicio se sigue aplicando** aunque el
volumétrico deje el cobro por debajo. El detalle técnico está en `RP-04b`.

---

### A4-02 · Caja puede subir un precio, no bajarlo — *a confirmar*

> "Lo de caja no debería de editar. Entonces solo lo hacen los que están en
>  pre-factura, los que autorizan, supervisor."
> "Ellos pueden agregar un producto y le pueden poner el precio… entonces, si
>  estamos que sean ciertos productos que ellos puedan agregar y modificar
>  precio, **pero para arriba**. Si lo bajan, entonces ya no."

**Lectura.** Caja puede **agregar** ciertos productos y ponerles precio, y puede
**subirlo**; bajarlo necesita autorización. Es un matiz de la regla de precio
bloqueado que ya estaba documentada (Fase 13).

Va marcado *a confirmar* porque el pasaje viene entrecortado en el transcript y
la regla mueve plata. **No se implementa hasta confirmarlo.**

---

### A4-03 · Por qué existe el mínimo de peso — *contexto*

> "El mínimo de ellos es lo que pesa la libra, o sea media libra o algo por el
>  estilo… la mayoría es una libra, pero para que, si le llega una pluma… le
>  cobramos media libra nada más, o punto 25, para que al cliente no le cobren
>  de más."

**Lectura.** El mínimo no es para exprimir al cliente sino lo contrario: evitar
cobrarle una libra entera a quien manda algo casi sin peso. Confirma el espíritu
de la tolerancia `.10/.60` que ya está implementada (A2-09).

---

### A4-04 · El formato del número de recepción — respalda RP-17

> "Sería **sucursal donde se recibió**, año y el mes… pero va a poner acá 12, el
>  mes, y el número."

Coincide con lo que escribió en la página 6. Ver `RP-17`.

---

### A4-05 · Regular y VIP **se eliminan** — mueve `RP-09`, *a confirmar*

Jorge le lee la pregunta 9 y Yusef contesta de una:

> Jorge: *"¿Qué hacemos con Regular y VIP? Hay 8 clientes en esta categoría."*
> Yusef: *"**Esas categorías ya no van**… ahora es el escalonado."*

Esto va **más allá** de lo que escribió en el papel, que solo decía
*"→ categorías actuales del Excel"*. El papel dejaba dudando si Regular y VIP
seguían existiendo; el audio dice que no: **desaparecen, y manda el escalonado**.

**Lo que sigue faltando** es lo mismo que faltaba: **a qué categoría pasan los 8
clientes** que hoy están ahí. Sin eso no se pueden migrar, así que `RP-09` no
cierra — pero deja de ser una pregunta abierta entera y pasa a ser una sola.

> ⚠️ *A confirmar.* Sale **solo del audio**, y el transcript es `tiny`. No se
> borra ninguna categoría hasta tenerlo por escrito.

---

### A4-06 · La tarifa de recolecta la crea un supervisor — detalle nuevo de `RP-10`

El papel ya había dado el precio (*"$35 o $25 dependiendo de la categoría de
precio de cliente, **es el mínimo a cobrar**"*). El audio agrega **quién la
carga**:

> *"…igual es editable… **crea la tarifa, pero por alguien que es supervisor**,
>  tipo Michelle."*

**Lectura.** Encaja con el patrón que ya usa el sistema en otros lados: el monto
lo puede mover alguien con autorización, no cualquiera. No cambia el modelado
que `RP-10` pide, lo acota: la edición del mínimo va detrás de un rol.

**`RP-10b` sigue abierta.** El audio habla de precios y de zonas de Miami, pero
**nunca contesta** si la recolecta de Miami y la de Honduras son uno o dos
cargos, que es lo que la pregunta pide.

> ⚠️ *A confirmar.* Solo audio.

---

### A4-07 · El flete de México se habla, pero no se entiende — `RP-13b`

Hay un tramo de casi un minuto sobre el flete de México y el mínimo, y el
transcript se cae ahí: números sueltos —cinco, seis, siete— sin frase que los
sostenga, y él mismo diciendo *"ahí fue que me equivoqué"* en el medio.

**No se documenta ningún número.** `RP-13b` (etiqueta internacional: precio y
moneda) **sigue abierta** y hay que volver a preguntarla. Se anota que el tema
salió en el audio para que nadie lo busque de nuevo pensando que se perdió.

---

## Las respuestas de las páginas 6 y 7

### RP-17 · El número de recepción: ¿le metemos el mes? — ✅ **CERRADA**

No marcó ninguna casilla: **escribió el formato**, rotulando cada parte.

```
R        MIA        26     12     ______________________
prefijo  sucursal   año    mes    número correlativo recepción
```

**Lectura.** Hoy es `RM` + `0002026` + `000010` → `RM0002026000010`.
Queda `R` + código de sucursal de 3 letras + año de 2 dígitos + mes →
`RMIA2612` + correlativo.

Dos consecuencias:

- El código de 3 letras **ya existe** (`Sucursal#codigo`: `MIA`, `SPS`, `TGU`,
  `SAM`), así que no hace falta catálogo nuevo. El
  `codigo_recepcion_prefix` actual (`RM`, `RS`, `RH`, `RSM`) queda obsoleto.
- El contador pasa a ser por **sucursal + año + mes**; hoy es solo por año.

Él ya sabía el costo — el papel lo decía: *"cambiarlo toca todos los números ya
generados, por eso no quisimos inventar"* — y aun así escribió el formato nuevo.
Como **no hay producción todavía**, se puede.

---

### RP-18 · Bajar la cantidad de cajas de un paquete — ✅ **CERRADA**

Marcó:

> ☒ Que deje hacerlo, pero **solo con PIN de supervisor**.

Y en el audio dio la razón:

> "Le pusieron 2 y al final es un paquete, y cuando van a entregar, el sistema
>  no va a querer entregar porque decía que eran dos. Va a ser un error así."

**Lectura.** Hoy `Paquete.ajustar_split!` **bloquea** el cambio si alguna caja
sobrante ya se cobró o entregó (`CajaNoEliminable`). Esa guarda deja paquetes
trabados en entrega. Pasa a ser: se puede, con PIN.

**IMPLEMENTADO en PR-C6.42.**

- `BajarCajasConPin` (mismo patrón que `QuitarCambioServicio`): lista de roles
  propia, PIN, y auditado por `paper_trail`. **No se toca `ROLES_AUTORIZANTES`**
  — esa lista da autorización sobre cualquier línea de pre-factura.
- Vive en **/paquetes** y no en /etiquetar: el problema aparece en Honduras,
  *"cuando van a entregar"*.
- **Desengancha antes de borrar.** Borrar la caja a secas no alcanza:
  `pre_factura_items` y `venta_items` la referencian con FK, así que el
  `destroy!` reventaría contra la base. Se le saca la línea a la pre-factura
  abierta y se recalculan los totales — si no, el cliente seguiría pagando una
  caja que ya no existe.
- **Dónde se planta el límite:** una caja ya **facturada**, con **venta**, o ya
  **entregada** no se baja ni con PIN. Eso es un documento fiscal o un hecho
  físico, y se corrige con una nota de crédito.
- **Sin PIN se sigue bloqueando**, con el mismo mensaje de hoy.

**Quién lleva el PIN (`RP-21`, contestado):** la lista se **deriva** de
`User::ROLES_AUTORIZANTES` —los cuatro renglones que Yusef marcó "SI"— más
`supervisor_miami`, que es Julien y es donde nace el error de digitación.
Derivada y no copiada a propósito: la primera versión, armada a criterio, se
había comido al **Supervisor de SAC**. Hay un test que fija que la lista sale de
la respuesta y no de un criterio nuestro.

---

### RP-19 · El campo de origen (China / Estados Unidos) — ✅ **CERRADA**, y **corrige lo que habíamos hecho**

No marcó "es solo informativo" ni "quítenlo". Escribió al lado de *"Cambia el
precio o el proceso"*:

> "Se utiliza para **el cobro** en Entrega Personal o en PreFactura."

**Lectura, y la corrección.** En `PR-C6.38` se concluyó que el origen era
**informativo** y se dejó derivado de la sucursal de recepción. La derivación
estaba bien —él nunca pidió un campo para teclear, y en el audio lo confirma:
*"si es en Miami, donde están recibiendo… si es fuera de ahí, ahí es donde está
eso"*—. **La conclusión no**: entra en el cobro.

Encaja con algo que ya está en pantalla: el panel de cálculo muestra **tres
formas** —`USA → HN` por libra o volumen, `USA → HN` por pie³, y **`China → HN`
por m³**— y hoy las tres se pintan siempre, con dos rotuladas *"no afluye en
precio"*. El origen es lo que decide **cuál aplica**.

Lo que el papel **no** dice es *cómo* multiplica. Eso queda como pregunta.

---

### RP-20 · El sonido de error del escaneo — ⏳ **abierta, pero ya se puede contestar**

**Sin marcar.** El papel dice *"te mandamos tres opciones por WhatsApp para que
las oigas"* — y **esas tres grabaciones nunca se hicieron**. No puede contestar
algo que no recibió.

> ✅ **Pagada (2026-08-11, `PR-275`).** Las tres existen:
>
> | Opción | Cómo suena |
> |---|---|
> | `grave` | **El que suena hoy.** Un tono bajo y seco de 0.3 s |
> | `descendente` | 440 → 220. El «respuesta incorrecta» de toda la vida |
> | `triple` | Tres pulsos cortos. Suena a alarma |
>
> Le llegan de dos formas: en `/etiquetar` y `/entrega_personal` —botón
> **Sonidos**, cada una con su «Escuchar»—, y como archivo en
> `docs/entregables/sonidos/` (`bin/rails docs:sonidos_wav`), para WhatsApp.
>
> Conviene que las oiga **en la pantalla**: un sonido de bodega se elige con el
> ruido de la bodega de fondo, no en el parlante de un celular.
>
> `grave` va primero y es el default a propósito: *"dejalo como está"* tiene que
> ser una respuesta posible. Cuando elija, se cambia el **default** de
> `sonido_error_variante` y ahí cambia para todos.
>
> **Lo que sigue abierto es solo su respuesta**, no nuestro trabajo.

Y de paso salieron dos cosas que el documento daba por hechas y no eran ciertas
— ver `A1-10` abajo.

---

### RP-21 · ¿Quién lleva PIN de supervisor? — ✅ **los roles, CERRADOS**

Escribió **"SI"** en los cuatro renglones: Administrador, Supervisor de Caja,
Supervisor de Pre-Factura, Supervisor de Servicio al Cliente.

**Lectura.** Esos cuatro son **exactamente** `User::ROLES_AUTORIZANTES`, que el
sistema ya tenía cargados desde `PR-13.c`. O sea que la parte de código de
`RP-21` **no estaba abierta**: la respuesta confirma lo que ya estaba.

Lo único que falta son los **nombres** de esas personas, y eso es **carga de
datos** —el admin les asigna PIN desde el CRUD de usuarios—, no una decisión que
bloquee ningún PR.

**Consecuencia para `PR-C6.42`:** la lista de `BajarCajasConPin` se **deriva** de
`ROLES_AUTORIZANTES` en vez de armarse a mano. La primera versión, escrita a
criterio, se había comido al **Supervisor de SAC** —que Yusef marcó "SI"
explícitamente—. Hay un test que fija que la lista sale de la respuesta y no de
un criterio nuestro.

Va aparte un renglón que el papel no tenía: el **supervisor de Miami** (Julien).
Lleva PIN por `PR-C6.28` —Yusef lo pidió en el audio, no en la hoja— y entra en
`BajarCajasConPin` porque es donde nace el error de digitación. **No** se le
agrega a `ROLES_AUTORIZANTES`: eso le daría autorización sobre cualquier línea de
pre-factura, que es mucho más de lo que pidió.

---

### RP-22 · Proveedores de entrega personal — ⏳ **pendiente de su oficina**

Escribió sobre la lista: **"Llenaremos en oficina"**. En el audio: *"eso lo puedo
grabar… por ahora aquí lo voy a dar yo"*.

---

### RP-23 · La etiqueta impresa — ⏳ **pendiente**

Escribió: **"Pendiente"**.

> "Esto es lo único que no podemos probar nosotros desde acá… vamos a poner con
>  una campaña y lo hago."

**Ojo con el orden**: ahora conviene que la imprima **después** de aplicar
`RP-17`, porque el número de recepción cambia y **va en el código de barras**.
Si la imprime antes, hay que repetirlo.

---

### Los tres pendientes que el papel le listaba

Siguen sin llegar, y el papel los nombra: **motivos de retención**, **notas
predeterminadas** y las **grabaciones de voz** para la alerta de pre-alerta.

---

### Lo que este cierre cambia de lo ya documentado

- **`RP-04b`** deja de estar SIN DEFINIR (A4-01).
- **`A1-25`** (origen del paquete) queda cerrada, **corrigiendo** la conclusión
  de `PR-C6.38`: no es informativo, entra en el cobro.
- **`A1-10`** (sonidos): el sonido feo espera que **nosotros** mandemos las tres
  opciones. Es deuda nuestra.
- **`A1-05`** (el sufijo de caja va en la recepción, nunca en el tracking) se
  mantiene, pero el número que lo lleva cambia de formato — ver `RP-17`.

### Preguntas nuevas que salen de estas respuestas

1. **¿`RP-19` y `RP-04b` son la misma cosa?** El origen China y el "solo volumen
   por cliente" apuntan los dos al cobro por volumen. ¿El origen lo decide solo,
   o siempre manda la configuración del cliente?
2. ~~**"Solo volumen": ¿es siempre el volumétrico**, o el mayor entre el
   volumétrico y algún mínimo?~~ — **cerrada por Jorge**: es siempre el
   volumétrico, y el **mínimo del servicio** se sigue aplicando aparte
   (`PR-C6.41`). Sin medidas se cobra el peso real, nunca cero.
3. **Los números de recepción viejos**: ¿se re-siembra staging para que todo
   quede con el formato nuevo, o conviven los dos?
4. **A4-02** (caja sube pero no baja): confirmar, que el transcript viene
   entrecortado y la regla mueve plata.

---

## Conversación 7 (2026-08-12) — la revisión del PDF de procesos, de punta a punta

1 h 50 min con Yusef y Manalo, repasando `procesos_para_yusef.pdf` página por
página. **Este audio es la respuesta a ese entregable**: cierra `RP-30`, corrige el
dibujo donde estaba mal, y de paso abre el frente de roles que llevaba meses
pendiente.

Alcanzaron a llegar hasta la página 3 de 12 antes de que se acabara el tiempo
(*"vamos por la página 3 de 12"*), pero Yusef dijo que el resto ya quedaba
prácticamente cubierto por lo hablado.

> ⚠️ **Sobre el transcript.** `whisper small` sobre audio de reunión con altavoz.
> Se le entiende bastante mejor que al del audio 4, pero se le van palabras y
> nombres. Se normalizaron las que no tienen ambigüedad —"onduras" → Honduras,
> "su cursal" → sucursal, "prefectura" → prefactura, "janear" → escanear— y **lo
> que no se entiende va marcado, no completado**.

---

### A7-01 · Bodega Honduras va **después** de la prefactura — ✅ **cierra RP-30**

El error más importante del diagrama, y Jorge lo tenía al revés:

> **Yusef:** "Bodega Honduras va después de prefactura."
> **Jorge:** "Ah, ok, prefactura antes de bodega, ok."

Más adelante lo repite con el porqué, que es lo que hay que documentar:

> **Jorge:** "Yo pensé que se iba a enviar primero y luego en el punto se hacía la
>  prefactura. ¿Por qué no se va a hacer la prefactura en San Pedro?"
> **Yusef:** "Porque **aquí tengo el personal para eso**. En Tegucigalpa no tengo,
>  no voy a tener otra persona haciéndolo."

**Lectura.** La prefactura se hace **siempre en San Pedro**, antes de mandar el
paquete a cualquier sucursal. No es una preferencia de orden: es que el personal
de prefactura existe solo en San Pedro. Esto tiene que quedar en el diagrama
(`lib/procesos_pdf.rb`) **y** hay que verificar que el flujo de estados no asuma
el orden viejo.

---

### A7-02 · El diagrama arranca en el portal del cliente, y ese es el canal minoritario

> **Yusef:** "El cliente solo hace ni... que **30, 40% de las prealertas**."

Yusef ordena las entradas al sistema:

> "Uno lo ve entrada, proceso, salida. Donde nace el paquete, esa es la entrada de
>  nuestro sistema. Veo que hay prealerta, escaneándolo en Miami, y hay otra
>  entrada que es una **digitación manual**, que no necesariamente en Miami, puede
>  ser desde aquí. Esas son las tres entradas."

**Lectura.** Tres puntos de nacimiento: pre-alerta (cliente o admin), escaneo en
Miami, y digitación manual — esta última es la etiqueta local que se hace en San
Pedro cuando en Miami se les escapó escanear. El diagrama solo dibuja el primero.

---

### A7-03 · El hueco entre manifiesto y aduana se llena escaneando la caja — ✅ **PLANIFICADO**

Es el hueco que el propio PDF marcaba con borde punteado:

> **Jorge:** "Acá está el hueco más grande, entre el manifiesto y la aduana. No hay
>  ninguna pantalla. Alguien entra a la ficha de paquetes y cambia el estado."
> **Yusef:** "Esto lo va a cambiar al **escanear la etiqueta de manifiesto en
>  caja**."

Y define el identificador:

> "Le vas a crear **un código QR o lo que vos querás**, el único código único de la
>  caja."

**Lectura.** Cada caja del manifiesto lleva su propio código. Ojo con
[[project_barcode_etiqueta_es_el_warehouse]]: el código de la **etiqueta del
paquete** es el warehouse receipt. Este es otro código, el **de la caja de
empaque**, y es nuevo.

---

### A7-04 · Se escanea primero la hoja del manifiesto, y eso lo "activa"

> "Vamos a escanear primero el [encabezado] que te va a imprimir el manifiesto en
>  la hoja principal, donde sale el desglose. Eso **te activa los otros paquetes**
>  para empezar a escanearlos."
> "En el instante que se están recibiendo, todos los paquetes que vienen amarrados
>  en ese manifiesto van marcándose como **aduana**."

**Lectura.** Escanear la hoja del manifiesto cambia el estado a *en aduana* y
habilita el escaneo de las cajas. Es el mismo gesto que ya existe en la
pre-factura y la factura (*"es como la prefactura, como la factura"*).

---

### A7-05 · La regla **no bloquea**: avisa y da dos salidas — ✅ **DECIDIDO en el audio**

Jorge preguntó explícitamente qué tan dura era la regla, porque de eso depende si
entorpece la bodega:

> **Jorge:** "Yo pregunto esto porque dependiendo qué tan dura querés esa regla.
>  Duro me refiero a que si definitivamente no la escanea y no está activada, **te
>  bloquea** el otro. Puede llegar a convertirse en un problema en el proceso."
> **Yusef:** "Fijate que hasta cierto punto tenés razón… **que no lo bloquee**."

Lo que sí hace, al finalizar:

> "Le va a decir: **falta la 2 de 3, falta la 8 de 10**… y te tira un listado."
> "Te va a dar la opción: **seguir escaneando** o **marcar como recibido con las
>  pendientes**."

Y queda visible fuera del momento del escaneo:

> "Igual si vos entrás como administrador, ahí deberías poder buscar… ya hay una
>  pendiente."

**Lectura.** Mismo patrón que el aviso de Miami: alerta con el faltante
enumerado, dos botones, y el pendiente queda consultable. **No bloquea el paso a
aduana del resto.**

---

### A7-06 · Miami → San Pedro: se escanean **cajas**, no paquetes

> "Escanearon cada caja, cada etiqueta de manifiesto. **No escanean los paquetes,
>  solo escanean las cajas.** Ya lo pone todo en aduana y listo, se cierra. Si
>  falta una caja, manda un correo al correo tal."

**Lectura.** El manifiesto internacional se cuadra a nivel de caja. El paquete
individual no se escanea acá. El faltante avisa por correo, no en pantalla.

---

### A7-07 · El manifiesto interno de sucursal es igual al oficial

> "Es el de envío nacional, de una sucursal a la otra. Lleva un **manifiesto
>  interno** y es igualito."

Con su horario y su tamaño:

> "El manifiesto de sucursal, el de Tegucigalpa, **lo recibe entre las nueve y
>  media y las tres de la tarde**."
> "Adentro del manifiesto, de uno a… cien paquetes. No creo que llegue a cien, por
>  cincuenta."

**Lectura.** Confirma [[project_dual_manifiesto_sonidos]]: dos manifiestos, mismo
comportamiento. El interno mueve el ~20% de la carga (*"el 80% de la carga se
queda en San Pedro"*).

---

### A7-08 · Escanear el manifiesto de sucursal notifica a todos, con ventana de espera

> **Jorge:** "¿Solo con que escanee el manifiesto le notifique a todos los clientes
>  en Tegucigalpa, o que escanee paquete por paquete?"
> **Yusef:** "Con el manifiesto notifique, pero **darle una ventana de media hora,
>  por ejemplo, o una hora**."

El motivo es operativo:

> "Yo veo que escanean el manifiesto y empiezan a escanear paquete por paquete
>  para cuadrar el manifiesto."

Y qué se manda:

> "El push del celular, el WhatsApp **o** el SMS —no lo vamos a atacar dos veces— y
>  el correo. El push y el correo es como permanente."

**Lectura.** Job encolado con retraso configurable (30–60 min) desde que se
escanea el manifiesto, para que el conteo termine antes de avisarle a la gente.
WhatsApp y SMS son excluyentes entre sí.

---

### A7-09 · Falta el estado **enviado a sucursal** (F7) — y existe por auditoría

> "Está el **F8** para consolidar en Honduras y el **F9** para notificar. Entonces
>  tenemos que crear un **F7**… que va para una sucursal."

Lo importante es para qué sirve:

> "¿Por qué va a servir ese status nuevo? **Porque esto sirve de auditoría.** Qué
>  paquete no escanearon o no enviaron… Se pueden ir a revisar el sistema y decir:
>  ey, este sale pendiente, hay que buscarlo. Y lo vamos a captar el mismo día o
>  el día siguiente."
> "A qué me refiero: que **los errores se corrijan en 24 horas**."

**Lectura.** F7 marca *pendiente de envío a sucursal*. No es cosmético: es el
gancho que permite detectar el paquete que se quedó sin empacar. Al cerrar el
manifiesto interno pasa a *enviado a sucursal*, **sin mandar ninguna
notificación** (*"solo en sistema va a cambiar el estatus"*).

---

### A7-10 · Falta el estado **consolidando Miami**, y detrás hay un servicio nuevo

> "Falta **consolidando Miami**… y eso no lo hemos creado tampoco en el etiquetar."

El porqué:

> "Creamos un servicio que se llama **COM, de consolidación**. Cuando el cliente lo
>  solicite por ese medio, entonces se queda consolidando en Miami."
> "La gente quiere consolidar 20 paquetes **allá**, no acá… y aparte quieren
>  devolver cosas. Dejan en Miami y de ahí devuelven algunas."

Hoy se resuelve a mano:

> "Me mandó 26 tracking… me puse a copiarle uno por uno y crearle la prealerta uno
>  por uno. Y después cambiar el estado a consolidado, **porque no existe ese
>  servicio todavía**."

**Lectura.** Un sexto servicio (`COM`) que hoy no existe, más su estado. Nota que
Yusef aclara que **no lo prende todavía**: *"si lo creo, tengo que tener listo
todo el personal en Miami… no tengo el espacio"*. Se documenta, no se activa.

---

### A7-11 · **Prefacturado no es un estado** — hay que sacarlo

> **Yusef:** "El prefacturado no sé de dónde lo sacó. Yo creo que lo sacó de los
>  procesos, **no del estatus. Ese tenés que eliminar.**"

**Lectura.** `prefacturado` está en la lista de estados del paquete y no debería.
Ojo antes de borrarlo: hay que ver si algún paquete lo tiene puesto y a qué se
migra.

---

### A7-12 · El dropdown de estados va ordenado por el proceso

> **Yusef:** "Prefacturado y disponible para entrega estaban antes. ¿No debería ser
>  primero…? A mí me gusta el orden."
> **Jorge:** "Como el proceso. Pero como ahora los metimos, solo están metidos."
> **Yusef:** "Hacéme la lista y yo la ordeno."

**Lectura.** Los estados salen en orden de inserción. Van en orden de flujo.
Yusef se ofrece a ordenar la lista si se la mandan.

---

### A7-13 · **Disponible en sucursal `<nombre>`** — y el porqué es una queja real

Yusef insistió mucho en esto, contra la resistencia de Jorge a alargar la lista:

> "Aquí llaman los clientes que cuándo van a recibir el paquete, y ya dice
>  *disponible en Honduras*."
> "Un cliente me dijo: recibí un WhatsApp que ya tengo disponible el producto, pero
>  entro a la página web y me dice que todavía no, que sale *aduanas* todavía.
>  **¿Cuál es el estatus real?**"
> "Han ido a recogerlo a Tegucigalpa y no está ahí."

Y cómo lo quiere:

> "*Disponible en sucursal Tegucigalpa*. *Disponible en sucursal SPS Cerón.*"
> "Es que recordá que **mi meta es abrir sucursales o puntos de entrega**."

**Lectura.** Dos cosas distintas: (a) el estado que ve el cliente tiene que nombrar
la sucursal, y (b) **la notificación y el portal se están contradiciendo hoy** —
eso es un bug, no una mejora. Yusef lo llama *"precontestarle la pregunta al
cliente"*.

Ojo: esto se cruza con la pregunta abierta de que **no hay sucursal de retiro
estructurada** (`Cliente` solo tiene `ciudad` en texto libre). Sin eso, el nombre
de la sucursal en el estado es tan confiable como lo que el cliente escribió.

---

### A7-14 · **Enviado**, no *en camino* — la semántica importa

> **Jorge:** "¿En camino sería mejor?"
> **Yusef:** "**No, enviado.** Porque *en camino* van a creer que ya va para ahí
>  ahorita, y van a creer que es ahorita."
> "Tenés que tener mucho cuidado con eso."

---

### A7-15 · **Entregado** lleva las iniciales de la sucursal; **en reparto** lleva KX o local

> "El entregado sería bueno poner ahí **las iniciales de la sucursal** donde se
>  entregó. Para no solo manejar nombre, sino unas iniciales para que uno pueda
>  entender en dónde se entregó."
> "En reparto había que poner que dijera **KX o local**."

**Lectura.** Las sucursales necesitan **nombre e iniciales** como datos propios.
KX es el repartidor externo; amarrarlo por API queda explícitamente para después
(*"eso queda para el futuro"*).

---

### A7-16 · F9 activa fecha **y hora** programada

> "**O** se activa la fecha programada… **fecha y hora** programada. Porque ahora lo
>  vamos a manejar hasta como hora, por si lo queremos programar para la tarde."

---

### A7-17 · El aviso de tracking existente tiene que ser un **modal que bloquee** — 🐛 **el error que encontró**

Este es el que Yusef anunció al principio (*"te encontramos un errorcito ahí que
se te quedó"*) y demostró en vivo al final:

> "Ya me tira esto, pero esto yo me refería que **me lo tirara como modal**. La
>  idea es que esto no te tira: **te tiene que bloquear la pantalla**, porque tenés
>  que usar una de las opciones obligadas de ahí."

Las opciones son tres:

> "Le da escanear y le preguntan qué vas a hacer: **actualización, cambio de
>  servicio, o es un duplicado**."

**Lectura.** Hoy el aviso sale inline y deja seguir trabajando. Tiene que ser
modal bloqueante con las tres acciones. Es chico y es el arreglo más fácil de
cerrar primero.

---

### A7-18 · El duplicado agrega una letra

> "Cuando es un duplicado le agrega **una letra**. Y si ya tiene otro duplicado,
>  agrega la [siguiente]."

---

### A7-19 · La pre-alerta se queda desincronizada del paquete — ✅ **ARREGLADO (PR-C7.02)**

Lo reprodujeron juntos y les costó entenderlo:

> **Yusef:** "Este tracking está en Express… **la prealerta era CER**, pero tenés
>  que actualizarla a Express."
> **Jorge:** "Por eso está haciendo este diagrama, porque **una inconsistencia
>  entre prealerta y paquete**."
> **Yusef:** "Ahí es donde tenés que irte a la prealerta y sacarlo de ahí."

**Lectura.** Al cambiar el servicio del paquete en `/etiquetar`, la pre-alerta
conserva el servicio viejo, y el siguiente escaneo vuelve a proponer el servicio
equivocado.

**La causa.** `Paquete#aplicar_cambio_servicio` toca solo el paquete, y **nada en
todo el repo escribía `pre_alertas.tipo_envio_id` después de crearla**. El único
callback que baja del paquete a la pre-alerta es `sync_pre_alerta_estados`, que
está condicionado al cambio de *estado* y solo toca el estado.

**Cómo se resolvió (`PR-C7.02`).** La pre-alerta sigue al paquete: un
`after_save` sobre `tipo_envio_id` que la sincroniza **cuando no hay duda** —si
todos los paquetes vinculados coinciden. Si divergen (dos cambios de servicio
distintos en la misma pre-alerta) **no se adivina**: se deja como está y queda
anotado en el historial, porque elegir uno sería inventarle un servicio al
cliente. Eso cierra `RP-33`: se corrige sola.

Yusef también pidió limpiar los datos de prueba: *"tenés que limpiar la base"*,
*"cuando hagamos pruebas mejor siempre trackings nuevos, para que todo quede
consistente"*. Ver [[project_base_dev_con_fixtures]].

---

### A7-20 · Entrega Personal: **caja por caja con Agregar**, no plantilla

Jorge propuso poner la cantidad de cajas y que el sistema replicara una plantilla
editable. Yusef lo rechazó tres veces:

> "**Nunca son iguales.** Las entregas personales nunca, nunca, nunca."
> "Yo he recibido 30 cajas: 10 son de uno, 5 son de otro, 10 son de otro, 2 son de
>  otro."

Y explicó por qué, que es lo que decide el diseño:

> "Ellos agarran la caja, miden, y de ahí se van a la computadora. **¿Cuáles cajas
>  eran? ¿Cuáles fueron las que ya metí?**"
> "Es **paso por paso**. Es igual el manifiesto de Miami."

**Lectura.** El operador mide una caja física y la mete; no tiene forma de saber
qué fila de una plantilla le toca. Va: llenar medidas y peso → **Agregar** →
siguiente. Si el tipo de caja existe en catálogo trae medida predeterminada y
solo se pide el peso.

Esto **contradice el diseño actual** y hay que rehacerlo.

---

### A7-21 · Las etiquetas salen al final, todas juntas, y sin "1 de N" — ✏️ **él mismo lo acotó (2026-08-19)**

> ⚠️ **Esto vale para el empaque, no para etiquetar.** Yusef lo corrigió solo en
> la llamada del 19-ago, sin que nadie se lo preguntara:
>
> > *"La etiqueta solo lleva el 1, 2 ni 3 porque no estamos seguros de cuántas
> > estamos empacando… **y no es en etiquetar. Etiquetar siempre lleva la
> > cantidad, porque ahí ya sabés cuántas mandás imprimir**."*
>
> Al recibir, la cantidad se fija antes de imprimir. Implementado en `PR-C7.28`
> con esa distinción; ver `C14-01`.

> "No creo que debamos crearle una etiqueta a cada uno a medida las vayamos
>  sacando, sino que **hasta el final tira las cinco etiquetas** y las pegás. Por
>  si hay algún cambio."
> "La etiqueta **solo lleva el número, no lleva el uno de dos ni de tres**, porque
>  no estamos seguros cuántas estamos empacando."
> "Cuando menos acordás: hey, me salieron cuatro en vez de cinco."

**Lectura.** La cantidad de cajas no se conoce hasta terminar de empacar, así que
ni la etiqueta lleva "1 de N" ni se imprime sobre la marcha.

---

### A7-22 · **Recolecta es una pre-alerta de Entrega Personal**

La definición más limpia que ha dado del módulo:

> "**La recolecta es como una prealerta de una entrega personal.**"
> "Acá en la entrega personal le podés dar una opción que diga que va a ser una
>  recolecta. Antes de proveedores."

Campos, todos aproximados:

> "Le vas a poner la cantidad de cajas que vas a ir a traer y un peso o medida
>  aproximada. **No necesitás exacto**, no todo es exacto."
> "El costo de recolecta automáticamente es **35**, y si el cliente tiene precio
>  especial es **25**."

**Lectura.** Misma pantalla que Entrega Personal con un switch al inicio. Genera
un *pre* warehouse receipt, no uno normal. El costo confirma
[[project_recolecta_tabla_tarifas]] con dos niveles.

---

### A7-23 · Recolecta necesita horarios, contacto e instrucciones

> "Hay unos campos que hay que agregar, que es **horarios**… horarios y la persona
>  encargada con número, información."
> "El paquete de Jorge Padilla me dijeron que preguntara por Manuel Quiñones, el
>  número de teléfono es tal, el horario de la empresa trabajan de 9 a 6."

**Lectura.** Tres campos nuevos: ventana horaria, persona de contacto con
teléfono, e instrucciones libres.

---

### A7-24 · Falta el impuesto de Miami — 💰

> "Nada más le está poniendo el **impuesto de Honduras**. Y ahí creo que hay que
>  poner el **impuesto de Miami**. Esto van a pagar en Honduras y aquí sería en
>  Miami."

**Lectura.** Es plata. Va con `RP-24`…`RP-29`.

---

### A7-25 · Hay **dos tablas de precios** que se pisan — ✅ **CERRADA (PR-C7.08 + PR-C7.12)**

Yusef encontró la duplicación navegando:

> "**Ya me acordé.** Yo hice categoría de precios al inicio, y después esta es la
>  que hice reciente. **Hay unas incongruencias.** No me había fijado que tenías
>  otra tabla del otro lado."
> **Jorge:** "Voy a tener que migrar, a ver cómo hago para unificar, porque en
>  teoría este servicio y la otra categoría **debería ser la misma tabla**."

Y falta lo escalonado en una de las dos:

> "Te falta categoría de precios más el **escalonado**. Porque en la categoría de
>  precios llevamos también precios escalonados."

**Lectura.** Dos modelos representando lo mismo. Mientras convivan, cuál manda es
ambiguo — y esto decide cuánto se cobra. Va con el bloque de plata.

**Cómo se cerró.** Nunca fueron dos tablas de precios: eran una tabla de precios
y una de grupos, con la segunda disfrazada de la primera.

`PR-C7.08` le quitó a `categoria_precios` las tres columnas de precio. No eran
"incongruencias" de contenido: **ningún cálculo las leía** desde `PR-C7.06`, y
encima las vistas las rotulaban en lempiras sobre números que estaban en dólares
—la tabla nunca tuvo columna `moneda`—. Se podían editar y no cambiaba nada de
lo que se cobra.

`PR-C7.12` cerró la otra mitad. Jorge, por segunda vez: *"el área de categoría de
precio, pensaría que se puede eliminar porque no le veo mucho valor"*. La tabla
**no** se puede eliminar —los 8 grupos son las 8 columnas de la hoja de Yusef y
28 de las 44 tarifas cuelgan de ellos; sin ellos el precio de Shein habría que
copiarlo cliente por cliente—, pero la **pantalla** sí sobraba: un CRUD de un
campo en el sidebar, justo debajo de "Tabla de Servicios". Se fue, y los grupos
se administran dentro de la Tabla de Servicios, que es donde vive su precio.

Queda una sola pantalla que cobra, que era el pedido de Yusef. Y un solo rótulo:
lo que la base llama `categoria_precios` se llama **"grupo de clientes"** en las
cuatro pantallas que lo muestran.

Lo escalonado que él extrañaba (*"en la categoría de precios llevamos también
precios escalonados"*) ya funciona igual para todos los niveles: cada fila de
`tarifas` es un escalón, con o sin grupo.

---

### A7-26 · El precio especial vive **en el cliente**, y aplica por servicio — ✅ **HECHO (PR-C7.15)**

> "Ese precio especial para un cliente **debería estar en el cliente**, digo yo.
>  Entro al [cliente] y le pongo el precio especial."
> "Le doy descuento en CER y en CEM, **pero no le doy descuento en EXPRESS**."
> "Si es mayorista, se va a aplicar **solo a los marítimos**."

La forma que acordaron:

> "Para mí tiene que ser un **megacuadro** para el cliente… un cuadro donde vaya
>  con todas esas, como seleccionamos."

Y la tensión de fondo, que conviene dejar escrita:

> **Manalo:** "Eso de tener un montón de precios siempre es mala idea."
> **Yusef:** "Lo que pasa es que en este negocio **vos negociás tarifas**."
> "Tenemos que unificar lo mejor que se pueda… estandarizar la mayoría y crearle
>  botones para las excepciones."

**Lectura.** Extiende el cobro por volumen de `PR-C6.41`: la misma matriz
cliente × servicio que ya existía para eso tiene que servir para el precio.

**Cómo se hizo.** El cuadro está en la ficha del cliente, donde él dijo que
entra, y **es una vista sobre `tarifas`**: escribe las filas de nivel cliente,
que ya eran el primer nivel de `Tarifa.resolver`. Guardar los precios del cliente
en otro lado habría vuelto a dejar dos fuentes de verdad para el mismo número —
o sea `A7-25` otra vez, tres días después de cerrarla.

Una fila por servicio, con cuatro cosas: **qué paga hoy y de dónde sale** (solo
lectura), **precio especial**, **mínimo** y **solo volumen**. Los checkboxes de
cobro por volumen se **mudaron** ahí; no quedaron duplicados.

Las dos columnas de la izquierda son la mitad que pedía Manalo. Yusef lo dijo
como *"estandarizar la mayoría y crearle botones para las excepciones"*: se ve el
estándar antes de pisarlo, y la excepción muestra cuánto se está bajando
(`−22% vs lista`). Por eso **no hay columna de descuento**: el descuento *es* el
precio especial, y una segunda forma de escribir el mismo número es justo lo que
se acaba de sacar del sistema.

Vaciar una celda **quita** la excepción, igual que en `PR-C7.14`. Y si un
servicio ya tiene tramos cargados, la fila sale en solo lectura con un link a la
Tabla de Servicios: una escalera no cabe en una celda, y ofrecer un número plano
la aplastaría en silencio.

**Lo que sigue abierto de este bloque**: *"si es mayorista, se va a aplicar solo
a los marítimos"* es una regla de la **categoría**, no del cliente.
`TarifasHuerfanas::SOLO_MARITIMOS` ya la detecta y la reporta con
`rake tarifas:huerfanas`; falta decidir si se corrige la data o la regla.

---

### A7-27 · Sin definir: ¿pie cúbico o libra volumétrica? — ✅ **CONTESTADA (`A8-02`)**

> **Jorge:** "¿Y si va a ser [pie] cúbico?"
> **Yusef:** "Eso es lo que hace falta todavía… si el cobro es **por pie cúbico o
>  por libra volumétrica**."

**Contestó el 2026-08-12**, en la hoja de redondeos: el cobro es **por libra
volumétrica**. El pie cúbico y el metro cúbico llevan escrito al margen *"pero
**no afluye en precio**"* — se calculan y se muestran, no multiplican. Ver
`A8-02`.

---

### A7-28 · Arranca la Conversación 2: el **Excel de roles × operaciones**

Lo primero que se habló, y es el frente que llevaba meses sin abrir:

> "Yo voy a crear un Excel donde tenemos arriba **qué roles**, y al costado
>  izquierdo **todas las operaciones que existen**, y vamos a tener que marcar
>  cuáles sí pueden hacer y cuáles no, para que vos lo creés."
> "Los de prefacturas **no pueden facturar**, solo pueden prefacturar. Y los de
>  facturas no pueden crear prefacturas, solo facturar."
> "Ahorita vos tenés un usuario de admin que puede hacer todo."

Quién lo hace y con qué expectativa:

> "Que **Evelin** me haga el Excel."
> "Como no nos vamos a acordar de todo, al final siempre va a irte aumentando. No
>  es como que te lo vamos a dar y no va a cambiar, **es mentira**."

**Lectura.** Yusef entrega la matriz. Del lado de código el enganche existe: los 9
roles y el concern `Authorization` (`require_role`, `can_access?`). Esto es lo que
por fin permite documentar la **Conversación 2**.

---

### A7-29 · Quién es quién

> "Vanessa tiene… los roles altos de administrativos. Ellos pueden hacer y
>  deshacer **lo mismo que yo**. El rol de ella, el de Vanessa y el mío es el
>  mismo: caja, prefactura, administrativo, todo."
> "Supervisor de caja sería **Michel**."

**Lectura.** Cuadra con [[project_quien_lleva_pin_rp21]]. El supervisor de caja es
un rol distinto del de prefactura y del de entrega: *"como es caja va a ser el
supervisor de caja, no va a ir el supervisor de prefactura"*.

---

### A7-30 · Pago parcial y crédito piden PIN

> "Siempre pago completo. Rara vez autorizamos pagos parciales, pero **para hacer
>  pagos parciales o crédito vamos a pedir PIN**, que lo va a poner el supervisor
>  de caja."

**Lectura.** Un caso nuevo para el candado de la Fase 13, que hoy cubre precio y
descuento pero no la forma de pago.

---

### A7-31 · "Necesitamos registro de todo" — el caso que lo disparó

Contando un problema real del sistema viejo:

> "Me salió **entregado pero no tenía ni factura ni nada**, no había pagado. Y yo
>  quise ver quién había dado la orden de entregar algo que no se ha pagado… **no
>  pude**. No pude ligar la entrega con la proforma que se escaneó."
> "Lo que necesitamos es poderle dar **seguimiento a cada cambio y cada cosa en
>  cada proceso, quién lo hizo. Necesitamos registro de todo.**"

**Lectura.** Es del sistema viejo, pero el requerimiento aplica igual. Enlaza con
[[project_paper_trail_global]] y con [[project_auditoria_whodunnit]]: `paper_trail`
ya registra quién desde `PR-C6.30`, pero **falta extenderlo** y falta que Entregas
guarde con qué documento se entregó.

---

### A7-32 · Varias pre-facturas en una sola factura

> **Yusef:** "¿No podés hacer que si al cliente le facturamos tres prefacturas le
>  haga una sola factura?"
> **Jorge:** "Podemos. Habría que hacerla bien ordenada la prefactura."
> **Yusef:** "Es mejor, porque **imprimimos menos papel** y tardamos menos."
> "Facturás una por una, o **marcás todas y facturás todas**. Y esta la quiero
>  aparte: entonces son tres marcadas, facturás esas dos y la otra aparte."

---

### A7-33 · Entrega: escanear factura, luego sus paquetes, y **una sola firma**

> "Escanear la primera, pipipe, escanear los paquetes; escanear la segunda, pipipe,
>  escanear los paquetes… y **una sola firma para todos** esos amarrados."

Y explícitamente **no** mezclarlos:

> **Jorge:** "¿O los cruzan?"
> **Yusef:** "No creo que sea buena idea, porque **me viene ahí en contra de
>  errores**."

**Lectura.** Va con el POD pendiente ([[project_pod_firma_entregado]]): la firma
es una por entrega, no una por factura.

---

### A7-34 · El acuerdo de foco: **terminar Miami antes de seguir**

Cerrando la reunión:

> **Yusef:** "Centrémonos en un área, Jorge. **Es etiquetar. Centrémonos en
>  Miami.** Terminemos Miami."
> "Entrada normal, entrega personal, recolecta."

**Lectura.** Confirma la regla que ya está escrita en `docs/entregables/README.md`
—solo se pregunta por el módulo en el que estamos— y fija el orden de trabajo:
las tres entradas de Miami antes de abrir prefactura.

Sobre prefactura Yusef fue claro en que todavía no toca:

> "Esta es la pantalla de prefactura, **no hemos llegado ahí**… cuando lleguemos
>  acá nos vamos a hablar dos meses."

---

### Punch-list de la Conversación 7

| Qué | Estado |
|---|---|
| Bodega Honduras después de prefactura (`A7-01`, `A7-02`) | ✅ `PR-C7.07` — dibujo corregido y regenerado; el pipeline de estados queda en `RP-38` |
| Modal bloqueante en `/etiquetar` (`A7-17`) | ⏳ **el más fácil, va primero** |
| Pre-alerta desincronizada del paquete (`A7-19`) | ✅ `PR-C7.02` — la pre-alerta sigue al paquete |
| Entrega Personal caja por caja (`A7-20`, `A7-21`) | ✅ `PR-C7.04` — repetidor con Agregar, y la etiqueta sin el `1 de N` |
| Estado `enviado a sucursal` / F7 (`A7-09`) | ✅ `PR-C7.03` — con `sucursal_destino_id` y fecha, que es lo que lo hace auditable |
| Sacar `prefacturado` de los estados (`A7-11`) | ✅ `PR-C7.03` — fuera del dropdown, sigue en el código |
| Ordenar el dropdown de estados (`A7-12`) | ✅ `PR-C7.03` — orden de proceso, desvíos al final |
| `Disponible en sucursal <nombre>` (`A7-13`, `A7-14`, `A7-15`) | ✅ `PR-C7.03` — **no estaba bloqueado**: `Cliente#sucursal_retiro` ya existía |
| Escaneo de manifiesto con aviso no bloqueante (`A7-03`…`A7-08`) | ⏳ Fase 12 |
| Recolecta como pre-alerta de EP (`A7-22`, `A7-23`) | ✅ `PR-C7.05` — switch en `/entrega_personal`; el `$25` sigue en `RP-10b` |
| Estado `consolidando_miami` (`A7-10`) | ✅ `PR-C7.03` — el estado sí; el **servicio `COM` no se activa** |
| Impuesto de Miami (`A7-24`) | 💰 va con `RP-24`…`RP-29` |
| Dos tablas de precios que se pisan (`A7-25`) | ✅ `PR-C7.06` — el fallback a la tabla vieja murió; el detector de huérfanas queda en `rake tarifas:huerfanas` |
| Precio especial por cliente y servicio (`A7-26`) | 🔨 el motor ya lo soporta (`tarifas.cliente_id`); falta moverlo a la ficha del cliente |
| Excel de roles × operaciones (`A7-28`) | ⏸️ lo manda Evelin |
| Varias prefacturas → una factura (`A7-32`) | 📋 Fase de facturación |
| Una firma por entrega (`A7-33`) | 📋 va con el POD |

### Las preguntas que abre

| Id | Qué |
|---|---|
| ~~`RP-31`~~ | ~~¿Pie cúbico o libra volumétrica?~~ (`A7-27`) — **✅ contestada** en la hoja de redondeos del 2026-08-12: **por libra volumétrica**; el pie cúbico *"no afluye en precio"*. Ver `A8-02` |
| `RP-32` | ¿De cuánto es la ventana de notificación al escanear el manifiesto de sucursal — media hora, una hora? (`A7-08`) |
| ~~`RP-33`~~ | ~~Al cambiar el servicio en `/etiquetar`, ¿la pre-alerta se corrige sola o se marca resuelta?~~ **✅ se corrige sola** cuando no hay ambigüedad — `PR-C7.02` |
| ~~`RP-34`~~ | ~~Los paquetes que hoy están en `prefacturado`, ¿a qué estado se migran?~~ **✅ no se migra ninguno**: el estado se queda, solo deja de poder elegirse a mano — `PR-C7.03` |
| `RP-35` | El Excel de roles × operaciones (`A7-28`) — lo hace Evelin |
| ~~`RP-36`~~ | ~~Nombre e iniciales de cada sucursal, y la sucursal de retiro estructurada en el cliente~~ **✅ ya existían**: `Sucursal#codigo` son las iniciales y `Cliente#sucursal_retiro_id` está desde antes. El doc que decía lo contrario estaba viejo |
| `RP-37` | **El impuesto de Miami** (`A7-24`): ¿qué tasa, sobre qué base, en qué servicios? Yusef solo dijo que falta. Y no es agregar una tasa: `impuesto` es una columna escalar en 5 tablas |
| `RP-38` | **¿Se reordena el pipeline?** Yusef dice *aduana → prefactura → bodega*, y el código tiene *aduana → disponible → prefacturado*, con `Paquete.facturables` exigiendo `disponible_entrega`. Cambiarlo decide **qué paquetes se pueden pre-facturar**, así que no se tocó |

---

## Conversación 8 (2026-08-12) — las reglas de redondeo, por escrito

No es un audio: son **dos mensajes de Yusef** con las reglas que faltaban, una
de ellas traída del contador. Van juntas acá porque hasta hoy vivían repartidas
entre comentarios de Ruby y nadie las podía consultar sin abrir el código.

Son **cuatro reglas distintas**, y confundirlas es fácil porque las cuatro se
llaman "redondeo".

| # | Qué se redondea | Regla | Código |
|---|---|---|---|
| 1 | **Libras y libras volumétricas** | umbrales `.10` y `.60` sobre la fracción | `VolumetricoCalculator.redondear_media_libra` |
| 2 | **Pies cúbicos** | **siempre hacia arriba** al entero | `VolumetricoCalculator.pies_cubicos` |
| 3 | **Metros cúbicos** | hacia arriba al **segundo decimal** | `VolumetricoCalculator.metros_cubicos` |
| 4 | **Dinero (L. y $)** | media redonda al **tercer decimal** | `ROUND_HALF_UP` en todo el cobro |

---

### A8-01 · Libra volumétrica: la regla al tercer decimal — 🐛 **el código no cumplía**

La tabla que mandó, con el ejemplo completo:

> **TARIFA USA A HN — POR LIBRA O VOLUMEN — LA MÁS COMÚN**
> PESO REAL 5 LBS · MEDIDAS 648 (ancho × largo × profundo, en pulgadas³)
> **ENTRE 166** → 3.90 VLbs → *"ES IGUAL A **4**"*
>
> | VLbs | redondeado |
> |---|---|
> | 3.099 | *"es igual"* **3** |
> | 3.10 | *"es igual a"* **3.50** |
> | 3.599 | *"es igual"* **3.50** |

Confirma dos cosas que ya estaban: el divisor es **166** y los umbrales son
`.10` / `.60`. Pero los dos valores de **tres** decimales destaparon un bug.

La regla estaba escrita **dos veces**. `VolumetricoCalculator` la resolvía en
milésimas con los umbrales literales; `Tarifa#redondear_al_incremento` le
restaba una tolerancia de `0.09` y hacía `ceil`. **No son equivalentes**: restar
0.09 y "por debajo de .10" coinciden en todo peso de dos decimales y se separan
en el tercero.

| peso | `Tarifa` (antes) | `VolumetricoCalculator` | **hoja de Yusef** |
|---|---|---|---|
| 3.099 | 3.5 ❌ | 3.0 | **3** |
| 3.599 | 4.0 ❌ | 3.5 | **3.50** |

Había un test que barría 4001 pesos obligándolas a coincidir — pero **en pasos
de 0.01**, o sea justo por encima de donde vivía la diferencia.

Estaba latente mientras `incremento_libras` venía en `nil`. `PR-C7.10` lo puso
en `0.5` en las 44 tarifas y lo volvió alcanzable: los pesos guardados son
`numeric(10,2)`, pero **`/cotizador` pasa `params[:peso]` crudo**, así que
cotizar 3.099 lb cobraba por 3.5 — media libra de más, en la pantalla que el
cliente ve antes de decidir.

**✅ Arreglado en `PR-C7.11`**: una sola implementación —la que valida la hoja—
y el barrido del test pasa a milésimas.

---

### A8-02 · Pie cúbico y metro cúbico **no afluyen en precio** — ✅ **cierra `A7-27` / `RP-31`**

Las otras dos tablas que mandó, las dos con la misma anotación al margen:

> **TARIFA USA A HN — POR PIE CÚBICO** · *"pero **no afluye en precio**"*
> 179424 pulgadas³ **entre 1728** → 103.8333 → **104** — *"**este siempre hacia
> arriba**"* (peso real 1000 lbs)
>
> **TARIFA CHINA A HN — POR METRO CÚBICO** · *"pero **no afluye en precio**"*
> 2.95 m³ · 450 kg
>
> | m³ | redondeado |
> |---|---|
> | 2.9301 | 2.94 |
> | 2.9400 | 2.94 |
> | 2.9401 | 2.95 |
> | 2.9402 | 2.95 |

Esto contesta la pregunta que quedó abierta en `A7-27` —*"eso es lo que hace
falta todavía: si el cobro es por pie cúbico o por libra volumétrica"*—:
**se cobra por libra volumétrica**. El pie cúbico y el metro cúbico se calculan
y se muestran, pero no multiplican nada.

Dos frases suyas hay que leerlas con cuidado porque están en taquigrafía:

- **"NO AFLUYE EN PRECIO"** = informativo. Se muestra, no se cobra.
- **"NO SE REDONDEA"** (sobre el metro cúbico) **no** quiere decir que se deje
  crudo — sus propios cuatro ejemplos suben `2.9301` a `2.94` y `2.9401` a
  `2.95`. Quiere decir *no se redondea al estilo media libra*: es hacia arriba
  al segundo decimal. Así estaba implementado desde antes.

El pie cúbico sí es un ceil puro al entero, tal cual dice.

---

### A8-03 · El redondeo del dinero: la respuesta del contador — ✅ **el código ya cumplía**

Venía de una pregunta nuestra sobre una diferencia de 3 centavos:

> **Pregunta:** 4 × 93.98 = 375.92, y con ISV 15% da 432.31. Pero el PDF dice
> 375.90 y 432.28. La diferencia de 0.03 — ¿cuál es la regla de redondeo?
>
> **Yusef:** *"¡Hay papito! Es que el programador anterior no entiende. Pero
> dejame, hablo con el contador y que me dé las reglas de redondeo."*

Y volvió con ellas:

> **Método de Redondeo — regla estándar**
> · Si el **tercer decimal** es ≥ 5, se redondea hacia arriba.
> · Si el tercer decimal es < 5, se redondea hacia abajo.
> · `L. 100.004 → L. 100.00` · `L. 100.005 → L. 100.01`

Es media redonda al segundo decimal, que es **exactamente lo que hace el sistema
nuevo**: `ROUND_HALF_UP` en los ~30 puntos donde se calcula plata —subtotales,
ISV, totales, descuentos, mínimos, notas de crédito y débito.

O sea que **`375.92` y `432.31` eran nuestros números, y estaban bien**. El
`375.90 / 432.28` del PDF era el sistema viejo **truncando** en vez de
redondear, y truncar siempre le cobra de menos a la empresa. No hay nada que
arreglar; quedó escrito para que no se vuelva a preguntar.

---

### Las preguntas que abre la Conversación 8

| Id | Qué |
|---|---|
| `RP-39` | La tolerancia de `.10`/`.60` está dictada **solo para media libra**. Si algún día se carga una tarifa con incremento de 1 lb, ¿la tolerancia sigue siendo la misma o es proporcional? Hoy no hay ninguna tarifa así, así que no bloquea nada |
| `RP-41` | **¿El flete de un envío de varias cajas se cobra por caja o por envío?** Hoy `PreFactura` arma una línea por caja, y cada una resuelve su propio escalón y su propio mínimo. Con las cajas de `A9-03` —5, 9 y 163 lb en CER— eso da **$633.50**; el mismo envío como 177 lb en un solo escalón daría **$619.50**. Nadie lo escribió, y son **$14.00 de diferencia en un envío**. La pantalla espeja lo que la factura cobra hoy (`PR-C7.17`) hasta que él decida |
| `RP-40` | El metro cúbico y el pie cúbico *"no afluyen en precio"* **hoy**. ¿Van a afluir alguna vez —China por m³, marítimo por ft³— o son informativos para siempre? Cambia si hay que guardarlos o basta calcularlos |

---

## Conversación 9 (2026-08-13) — la etiqueta y el WR de un envío real, marcados a mano

Yusef mandó por WhatsApp la etiqueta y el Warehouse Receipt de un envío de
3 cajas (`RMIA2608000001` / `EP-2026-SMI-WAL-000003`), con anotaciones en rojo
sobre las imágenes y una nota de voz de minuto y medio explicándolas.

> ⚠️ **Sobre el transcript.** `whisper small` sobre nota de voz de WhatsApp. Oye
> *"World Health Receipt"* donde él dice **Warehouse Receipt**; queda
> normalizado. Lo demás va como salió.

---

### A9-01 · La etiqueta dice "RETIRA EN MIAMI" — 🐛 ✅ **ARREGLADO (PR-C7.16)**

Anotado sobre el recuadro de la etiqueta:

> *"Retira en la sucursal asignada al cliente, **al igual que etiquetar**."*

Y en el audio: *"la etiqueta solo tiene esos dos defectitos, verdad, que no es
nada del otro mundo"*.

**Qué pasaba.** `Paquete#sucursal` es, textualmente en el modelo, *"dónde RETIRA
el cliente"*. `/etiquetar` lo respeta: manda la sucursal donde se está
recibiendo a `sucursal_recepcion` y deja `sucursal` para heredarla del cliente.
`/entrega_personal` mandaba la sucursal de Miami como `sucursal_id`, o sea que
ocupaba el campo del retiro — y la etiqueta imprimía lo que encontraba ahí.

Su comparación con `/etiquetar` era exacta: esa pantalla ya lo hacía bien.

---

### A9-02 · El Warehouse Receipt "solo sale por una caja" — 🐛 ✅ **ARREGLADO (PR-C7.16)**

> *"Dos: el Warehouse Receipt sí está malo, porque **solo sale por una caja**.
>  Y el Warehouse Receipt es cuando vos le entregás al cliente que recibiste las
>  tres cajas."*

Y la distinción que hay que tener clara, porque es la que ordena todo el flujo:

> *"Esa etiqueta… es **la etiqueta que nosotros le pegamos a cada caja**, pero
>  pido tres. Pero al contrario, el Warehouse Receipt es al revés: el Warehouse
>  Receipt **solo imprimís uno**, donde detalla todo lo que recibiste y toda la
>  información que ya le pusiste."*

Sobre la imagen, al lado del `-1` del código de barras:

> *"Agregue detalle de 3 cajas, aquí debería crear las etiquetas para 3 cajas y
>  luego tirar preview del WR."*

**La causa era una sola, y no estaba en el WR.** Los trackings autogenerados
—`EP-` y `RC-`— salen de un callback cuyo único guard es `tracking.blank?`, y
`crear_split!` crea las cajas en un loop: cada caja sacaba **su propio número**
(`…000003`, `…000004`, `…000005`) y el contador avanzaba tres veces.

Y todo lo que agrupa un split lo hace por `tracking` —`paquetes_hermanos`,
`wr_packages_for`, `etiqueta?hermanas=1`—, así que los hermanos eran **cero**. De
ahí salía lo que él vio: el WR listaba una fila y `TOTAL PIECES 1` mientras el
badge de al lado decía `SPLIT 3 CAJAS`.

Contradecía además lo ya decidido: **un tracking, N cajas**.

---

### A9-03 · Al WR le falta el total de libras que se va a cobrar — ✅ **HECHO (PR-C7.16)**

> *"Entonces aquí es donde le tenés que poner la medida de las tres cajas, el
>  total de las tres cajas, etcétera. El valor total de libras que se le va a
>  cobrar, etcétera. **No es valor de precios, sino es valor de libras que se le
>  va a cobrar, el que sea mayor en cada transacción.** O sea, si una caja pesa
>  más y la otra tiene más volumen, entonces le vas poniendo el de mayor **de
>  cada una individual**."*

Es **suma de los máximos por caja**, no el máximo de las sumas — y no dan lo
mismo. Con las tres cajas del ejemplo (5 lb / 8 lb / 2 lb pero 30×30×30):

| | |
|---|---|
| Peso real total | 15.0 lb |
| Volumétrico total | 176.5 lb |
| **Libras a cobrar** | **177.0 lb** |

El número que factura no aparecía en el documento y no se deducía mirando las
otras filas. Sale de sumar `peso_cobrar`, que cada caja ya calcula con la regla
completa.

---

### A9-04 · El resto del WR no se toca: es de pre-factura

> *"La otra: en el servicio… todo esto es parte que va en **prefactura**. Por eso
>  yo no te he explicado estas partes."*
> *"De ahí parece que el Warehouse Receipt está bastante bien, que lo vimos una
>  vez pasada."*

Acota el alcance: el WR lleva **pesos y medidas, no plata**. El precio, el ISV y
el valor declarado son del documento que viene después.

---

## Próximos Pasos

1. **Conversación 2:** Login, Logout, Creación de usuarios y roles — **arrancó en
   `A7-28`**: Yusef manda el Excel de roles × operaciones (`RP-35`)
2. **Conversación 3:** Detalle de Paquete Interno + Warehouse Receipt — ✅ documentada arriba, preguntas del bloque PR-D todas resueltas
3. **Conversación 4:** ✅ documentada arriba — franja de contexto operativo (PR-9)
4. **Conversación 5:** ✅ documentada arriba — tarifas, mínimos y etiqueta (PR-10)
5. **Conversación 6:** ✅ documentada completa — los tres audios, las 3 páginas
   de notas de Jorge, las respuestas de Yusef al PDF, su página de notas y la
   etiqueta anotada (`A1-01`…`A1-28`, `A2-01`…`A2-14`, `A3-01`…`A3-12`,
   `RP-01`…`RP-23`, cruce `N`).
6. **Conversación 7:** ✅ documentada arriba — la revisión del PDF de procesos
   (`A7-01`…`A7-34`). Cierra `RP-30` y abre `RP-31`…`RP-36`.

### Lo que salió implementando (2026-08-09 / 10)

Cosas que **nadie reportó** y aparecieron al tocar el código. Van acá para que
no se pierdan y para que las que son preguntas lleguen a Yusef.

| Qué | Dónde quedó |
|---|---|
| El **audit log nunca registró quién**: `respond_to?` sin el flag de privados devolvía false, así que el hook nunca corría. Los 41 modelos guardaban qué cambió, nunca quién | ✅ `PR-C6.30` |
| El botón **"Guardar (F8)" de `/pre_alertas/edit` no hacía nada**, y borrar una fila tampoco persistía | ✅ `PR-C6.25` |
| En **Entrega Personal la cantidad de cajas se perdía**: dos campos con el mismo `name`, ganaba el hidden con valor 1. Y EP nunca aplicó el peso por caja | ✅ `PR-C6.31` |
| **Ocho copias** de la misma búsqueda con dropdown. Las ocho pedían 2 caracteres, dos preseleccionaban, cuatro tenían flechas | ✅ `PR-C6.32` a `PR-C6.34` |
| **Tres vistas** cableaban un autocomplete sin mandarle el `keydown`: el JS sabía navegar, la vista nunca le pasaba las teclas | ✅ `PR-C6.34` + lint |

### Preguntas nuevas para Yusef (salieron del código, no de él)

1. **No existe una sucursal de retiro estructurada.** `Cliente` solo tiene
   `ciudad`, texto libre, y `/etiquetar` nunca setea `paquete.sucursal`. El
   aviso de "separar por sucursal" (`A3-07`, `PR-C6.24`) muestra ese texto,
   así que es **tan confiable como él**: si un cliente dice "Tegus" y otro
   "Tegucigalpa", Miami arma dos bolsas. Para que separar por sucursal
   funcione de verdad hace falta una sucursal real en el cliente.
2. **La tasa de cambio: quién la mantiene y cada cuánto.** Ya está en 27.10 y
   tiene su pantalla (`PR-C6.29`), pero nadie dijo quién la revisa.
3. **PIN para Julien.** `PR-C6.28` deja listo que el supervisor de Miami
   quite el cobro por cambio de servicio, pero hoy el banner avisa que nadie
   puede autorizar. `RP-21` ya llegó y cerró los roles: falta **asignarle el
   PIN** desde el CRUD de usuarios, no una decisión.

### Lo que sigue (2026-08-09)

1. ~~**Faltan las fotos de `RP-17`…`RP-22`**~~ — **llegaron** (páginas 6/7 y
   7/7, con el audio 4). `RP-21` quedó cerrada del lado de código: los cuatro
   roles que marcó ya eran `ROLES_AUTORIZANTES`.
2. **Ronda 2 de preguntas**: `RP-01`, `RP-02`, `RP-09` (solo el destino de los 8
   clientes), `RP-10b` y `RP-13b`, más los recordatorios de `RP-15` y `RP-16`.
   `RP-04b` **sale de esta lista**: cerró en `A4-01` y ya está implementada en
   `PR-C6.41`. **No se pisa** `preguntas_para_yusef.pdf`: es el que él contestó.
3. **La pista de plata**, en este orden y verificando en staging entre paso y
   paso: `C6.18` (bug de frontera) → `C6.29` (tasa 27.10) → `C6.20` (activar el
   redondeo) → `C6.19` (informe de impacto). El informe se le lleva junto con
   la hoja 2 del Excel, que sigue sin revisar (`RP-16`).
4. **La pista de Miami**: `C6.24`, `C6.25`, `C6.26`, `C6.28`.
5. ~~**Conversación 2** sigue siendo la única sin documentar.~~ — **arrancó** en
   `A7-28`: Yusef ofreció el Excel de roles × operaciones (`RP-35`).

### Lo que sigue (2026-08-12, después de la Conversación 7)

Yusef fijó el foco y conviene respetarlo: **terminar Miami antes de abrir
prefactura** (`A7-34`). El orden que sale de eso:

1. **El modal de `/etiquetar`** (`A7-17`). Es el error que él encontró probando,
   es chico, y es lo primero que va a volver a mirar.
2. **La pre-alerta desincronizada** (`A7-19`) — mismo módulo, mismo escaneo.
3. **Entrega Personal caja por caja** (`A7-20`, `A7-21`). Contradice el diseño
   actual, así que es rehacer, no ajustar.
4. **Recolecta** (`A7-22`, `A7-23`) — es la tercera entrada de Miami y la
   definición ya está completa: es una pre-alerta de Entrega Personal.
5. **El PDF de procesos corregido** (`A7-01`, `A7-02`) y regenerado, para
   devolvérselo con el orden bueno.

Los estados (`A7-09`…`A7-16`) son un bloque aparte: tocan migración, badges y el
dropdown, y varios están bloqueados por la sucursal estructurada (`RP-36`).

**La pista de plata**: de lo que había abierto el 2026-08-12 quedan el impuesto
de Miami (`A7-24`, sigue esperando definición) y el bloque `RP-24`…`RP-29`. Las
dos tablas de precios que se pisaban (`A7-25`) se cerraron el mismo día con
`PR-C7.08` y `PR-C7.12`, y las reglas de redondeo quedaron escritas y
verificadas en la Conversación 8.

---

## Conversación 10 (2026-08-14) — cómo se recibió el pago en Miami

Jorge, después de probar el prepago en staging:

> *"Ya vi el pagado en Miami, está bien. Solo faltó algo que conversamos: que
> escogieran **cómo se pagó**. Efectivo o Zelle o TC."*

Y al preguntarle en qué pantallas:

> *"Esto es en la parte de Miami — **etiquetar y entrega personal** — hay que
> mostrar cómo se pagó."*

### C10-01 · El método de pago del prepago — ✅ **CERRADA e implementada**

`prepagado_miami` guardaba quién, cuándo y en qué sucursal, pero **no con qué**.
El cajero de Honduras armaba el cobro simbólico sin saber si había entrado
efectivo, Zelle o tarjeta.

**Lo que se hizo:** columna `prepagado_miami_metodo` con
`%w[efectivo zelle tarjeta]`, obligatoria al marcar el prepago y prohibida si no.
Se muestra en la ficha del paquete, en el badge del Warehouse Receipt
(`✓ PREPAGADO EN MIAMI · ZELLE`) y en el concepto de la línea simbólica de la
pre-factura.

> **La lista NO es la de la caja.** `Pago`, `IngresoCaja` y `EgresoCaja` comparten
> `%w[efectivo tarjeta transferencia]` —la misma lista escrita tres veces— y
> **Zelle no se recibe en Honduras**. Son dos listas distintas a propósito, con
> un test que lo fija. La triplicación de la otra queda como deuda: consolidarla
> toca la caja, que es plata en vivo.

### C10-02 · `/etiquetar` no tenía el prepago — ✅ **CERRADA**

Al ir a implementar apareció que **el marcado existía solo en
`/entrega_personal`**. Las dos pantallas de Miami hacen lo mismo y una se había
quedado atrás sin que nadie lo decidiera — el bug recurrente de este repo.

Ahora las dos comparten `shared/_prepago_miami` y el concern `PrepagoMiami`, con
un lint que impide volver a escribirlo a mano en cualquiera de las dos.

**De paso se cerró un hueco viejo:** el sellado solo actuaba en la rama `true`,
así que **desmarcar el prepago dejaba puestos** la fecha, el usuario y la
sucursal de un cobro que ya no existía.

### C10-03 · La suma de libras del panel — ⏳ **ABIERTA**

> *"Solo que tiene malo la suma de libras para cobrar."* · Y al ubicarlo:
> *"en el panel de cálculo mientras cargo"*.

La suma de las cajas **ya agregadas** está bien: es el mayor de cada caja y
después se suman, que es la regla `A9-03`. Lo que falta es que **la caja que se
está escribiendo todavía no cuenta** — `calc_volumetrico_controller` lee solo
las filas `.caja-fila` ya confirmadas. Jorge lo confirmó. Va en su propio PR.

---

## Conversación 11 (2026-08-17) — la tanda de WhatsApp después de probar staging

Yusef probó de punta a punta y mandó una lista. Cerró con *"va agarrando muy muy
buena forma"*, y confirmó que **funcionan** el escaneo de USPS, el tracking de
FedEx y el prepago de Entrega Personal.

**Dos cosas de su lista no entraron, porque él mismo se corrigió**: lo de *"F9 no
me pregunta cuántas etiquetas"* lo cerró con *"ya vi dónde está el clavo… es una
inconsistencia mía, en cuanto a editar y recibir carga variada sin medir y sin
pesar"*.

### C11-01 · Los avisos que no avisan — 🐛 ✅ **ARREGLADO (#304)**

Lo reportó **dos veces**: *"no me da la información de que es de Sucursal de
Tegucigalpa"* y *"también misma situación no avisa que va a tegus"*.

Eran dos causas del mismo tipo de falla. En `/etiquetar`,
`_fillClienteFromPreAlerta` era una **copia** de `_alSeleccionarCliente`: se
copiaron las notas del cliente y se olvidó el aviso de sucursal — el comentario
del propio código decía *"misma lógica para mantener consistencia"* y no lo era.
En `/entrega_personal` el aviso **no existía**.

Los dos fallaban en silencio: nadie se entera de un aviso que no salió. Ahora
los tres caminos que fijan cliente pasan por un solo gancho, el aviso sale de un
partial compartido, y hay lint de las dos cosas.

De la misma tanda: *"aquí no me dio alerta del Secundario"* — el input del
tracking secundario no tenía **ninguna** acción, así que un repetido no avisaba y
lo que escupía la pistola entraba crudo.

### C11-02 · La pre-alerta de admin — 🐛 ✅ **ARREGLADO (#305)**

> *"No marqué consolidado y me deja agregar más de 1, siempre en admin."*
> *"Nos hace falta la opción de Retener en Miami en Pre Alerta de Admin."*

La regla de consolidación existía en el portal pero **solo en la vista**. Pasó a
ser validación de modelo, y corre solo al crear o cuando cambia la cantidad de
paquetes: una pre-alerta vieja que ya está así se sigue pudiendo guardar. Es la
misma trampa del método de prepago.

`retener_miami` es columna nueva en `pre_alerta_paquetes` y viaja al paquete
esperado. **Va la bandera, sin motivos**: el motivo se sabe cuando el paquete
llega y se etiqueta, que es donde ya se pide.

> ✅ **El hueco que quedaba acá se cerró en `PR-C7.27`.** El checkbox de
> retención de `/etiquetar` arrancaba desmarcado, y un checkbox desmarcado manda
> `"0"` — así que **el escaneo apagaba la bandera** que la pre-alerta acababa de
> traer. Ahora `detect_pre_alerta_match` la devuelve y el autofill la marca en la
> pantalla; el operario la puede desmarcar, que era la condición.
>
> Y la decisión de que la pre-alerta llevara *"la bandera, sin motivos"* también
> se revirtió ahí: los motivos y la nota se guardan en el **paquete esperado**,
> que ya tiene esas columnas — la tabla de join que me la había hecho descartar
> nunca hizo falta. Ver `C13-01`.

### C11-03 · Entrega Personal: el Contenido — ✅ **ARREGLADO (#306)**

> *"Entrega personal, es obligatorio poner contenido, y debería ir más arriba,
> después de tipo de envío."*

Un paquete de courier llega con la descripción del carrier; el que entra al
mostrador de Miami no trae nada escrito, y sin eso la etiqueta y el Warehouse
Receipt dicen cuánto pesa pero no qué es. Obligatorio al crear o al tocar el
campo —los EP viejos sin contenido se siguen pudiendo guardar— y el campo subió
a la altura del tipo de envío.

### C11-04 · El Warehouse Receipt que no le salía — 🐛 ✅ **ARREGLADO (#307)**

> *"Falta la observación que te hice: si después de imprimir la etiqueta, te
> tire automáticamente el Recibo de Bodega."*

El código **sí** lo hacía desde `PR-C7.16`. A Jorge se le abrían las dos
ventanas; a Yusef no. Jorge pidió no dar por sentado el bloqueador de popups.

**Reproducido**: Chrome le da permiso a un gesto del usuario para **un** popup,
no para dos — el segundo `window.open` se cae en silencio. A Jorge le funcionaba
porque su Chrome ya tenía el permiso dado para el sitio.

Ahora se abre una sola ventana y ésa, al terminar de imprimir, **se va** al
Warehouse Receipt en vez de cerrarse.

> ⚠️ **De paso salió una trampa del harness.** El Chrome de los system tests
> **no bloquea popups** (chromedriver lo arranca con `--disable-popup-blocking`),
> así que un test escrito de la forma normal daba verde con el bug puesto. Hay un
> driver aparte, `:chrome_con_bloqueador_de_popups`, para cuando haga falta.

---

## Revisión integral (2026-08-17) — el paquete fantasma

Salió del repaso de punta a punta que pidió Jorge —pre-alerta → paquetes →
etiquetas → WR—, no de un reporte de Yusef.

### RI-01 · Un tracking pre-alertado que llega dividido — 🐛 ✅ **ARREGLADO (PR-C7.20 · C7.21 · C7.22)**

`create_single` reconciliaba contra el paquete que la pre-alerta dejó esperando;
**`create_split` no**. Un tracking pre-alertado que llegaba en varias cajas
dejaba tres registros con el mismo tracking:

```
id=…102  estado=pre_alerta_estado  caja=nil  peso=nil     ← el fantasma
id=…103  estado=recibido_miami     caja=1    peso=12.5
id=…104  estado=recibido_miami     caja=2    peso=30.0
```

Y de ahí: **3 etiquetas para 2 cajas** —la de más con `—` donde va el número de
recepción—, el Warehouse Receipt declarando **3 piezas**, y la pre-alerta
congelada en `pre_alerta`: el cliente la veía "en camino" con el paquete ya en
Miami. El cobro no se veía afectado — el fantasma se queda en
`pre_alerta_estado` y la pre-factura solo agarra paquetes disponibles.

No se reparaba solo: `link_tracking!` filtra por `sin_vincular`
(`paquete_id: nil`) y esa fila **ya apuntaba** al fantasma — invisible para su
propio reparador.

**Jorge eligió que el esperado se vuelva la Caja 1** (y no borrarlo y
re-apuntar): conserva id, guía y bitácora. Reusar la caja 1 y no otra tampoco es
casualidad — `ajustar_split!` solo borra `numero_caja > m`, así que es la única
que sobrevive a subir y bajar la cantidad de cajas.

La reconciliación salió a un concern compartido por las dos rutas; quiénes son
"las hermanas" de una caja se decide en un solo lugar y excluye lo que no llegó;
y una migración de datos reconcilia los fantasmas que ya estaban grabados,
saltando y reportando los que ya entraran a una pre-factura, venta, nota o
reempaque.

---

## Conversación 12 (2026-08-18) — la videollamada probando staging

42 minutos con la pantalla compartida, probando lo que se había subido el día
anterior. Transcrita con `whisper small`.

**Lo que dio por bueno, probándolo en vivo:**

| Qué | Lo que dijo |
|---|---|
| El paquete fantasma (`RI-01`) | *"Ahora, si te entran dos paquetes, pues dos paquetes te quedan."* |
| El aviso de sucursal (`C11-01`) | *"Sí me dice el TEGUS, excelente. Esto está bien aquí."* |
| La retención con motivos | *"Ahí se ha retenido… de esa manera nosotros tenemos menor error al verlo."* |
| El cambio de servicio | *"Está saliendo bien."* |

Y cerró: *"ahí va agarrando forma… ya hay mejor entendimiento de los dos lados"*.

> El Warehouse Receipt encadenado (`C11-04`) no alcanzó a probarlo: la
> computadora se le trabó dos veces durante la llamada.

### C12-01 · Si no se midió nada, preguntar cuántas etiquetas — ✅ **ARREGLADO (PR-C7.23)**

Lo repitió **tres veces**, la última al despedirse: *"acordate, no se te olvide
corregir que si sale cero aquí, pregunte cuántas etiquetas"*.

> *"En etiquetar casi nunca medimos y pesamos."*
> *"Cuando la cantidad de cajas guardadas sea cero, que pregunte cuántas son."*

El caso normal de Miami es recibir sin medir, y eso grababa **un** bulto y sacaba
**una** etiqueta aunque el envío trajera tres cajas.

**Tres etiquetas son tres cajas**, no tres copias del mismo papel: el flete se
cobra por caja, el WR cuenta piezas y cada etiqueta lleva su `1/3`.

Esto ya había cambiado tres veces —`PR-C6.17` lo preguntaba en F9, `PR-C6.18b` lo
quitó porque *"el F9 era como confuso"*, `A7-20` sacó también el campo del
formulario— y siempre por lo mismo: que haya **una sola fuente** para el número.
Vuelve a preguntar con la condición que lo hace distinto: **solo cuando no hay
ninguna caja cargada**. Jorge lo planteó en la llamada —*"no pueden ser los dos,
voy a tener dos variables"*— y Yusef aceptó.

### C12-02 · Las cajas de un split salían separadas en el listado — 🐛 ✅ **ARREGLADO (PR-C7.24)**

> *"Lo único que no entiendo es por qué está separado, deberían de estar
> juntitos. Porque eso puede ocasionar errores."*

Causado por `RI-01`: con la reconciliación, la Caja 1 **es** el paquete esperado
y conserva la hora en que el cliente lo anunció (11:11), mientras la Caja 2 nace
al etiquetar (11:34). El listado ordenaba por fecha de creación.

Él lo cerró con una regla más ancha que el síntoma:

> *"Todas las actualizaciones tienen que ir con la última hora… si un paquete
> está disponible en Honduras, se tiene que actualizar con la hora que se marcó
> que estaba disponible."*

El orden por defecto pasa a la última actualización, y la primera columna lleva
la hora — *"aquí ocupamos la hora en esto"*.

### C12-03 · El tracking no se ve completo — ✅ **ARREGLADO (PR-C7.25)**

> *"El tracking necesitamos verlo completo… si no, vamos a tener que estar
> entrando a cada tracking para poder encontrar uno."* · *"Para querer leérselo
> al cliente."*

Salía recortado a 18 caracteres y los de USPS pasan de 30. Es la misma regla que
ya valía para la etiqueta impresa y que nunca había llegado al listado.

El ancho salió de donde él lo señaló: *"le puedes poner «rep Miami»… «hn», no
pones Honduras sino que «hn», cosas así"*. Los estados de la tabla pasan a un
rótulo corto.

> ⚠️ **Los rótulos largos no se tocaron.** Son los que ve el cliente y los peleó
> él mismo en `A7-13`. Son dos audiencias distintas: el cliente necesita la frase
> entera, el operario necesita el ancho. El largo quedó en el `title`.

### C12-04 · El segundo tracking también anunciado — 🐛 ✅ **ARREGLADO (PR-C7.26)**

Un bulto llega con dos códigos —el del carrier y el del comercio— y el cliente
pre-alerta uno, o el otro, o los dos. Escaneó el segundo y le salió el modal de
duplicado:

> *"Esto, según tus reglas del inicio, no debería pasar… aquí está agarrando la
> regla de que existe el tracking y no la regla de que es una pre-alerta."*

La regla que dictó, con sus dos mitades:

| Lo que compara | Qué pasa |
|---|---|
| Mismo cliente **y** mismo tipo de envío | *"No es necesario hacer nada"* |
| Cliente distinto **o** tipo de envío distinto | *"Hay una diferencia en el tipo de envío"* · *"está a nombre de dos personas diferentes"* |

**El aviso no marca nada solo.** Jorge preguntó derecho —*"¿el sistema va y marca
la casillita?"*— y contestó que no: *"ahí mismo le dice: este paquete tiene dos
tipos de envío. Lo va a retener, o lo va a enviar así"*.

Y la otra mitad, la del guardado: *"tiene que jalar esta información,
compararlo, venir y unificarlos acá y eliminarlo de la pre-alerta. **No es
vincularlo, eliminarlo**"*. El esperado del secundario quedaba huérfano igual que
el fantasma de `RI-01`, por la otra puerta.

Frecuencia, según él: *"normalmente va a ser uno o el otro… te voy a dar un 80%
de los casos"*; el 20% los dos, y *"el 5% le voy a dar que va a haber un error en
algo"*.

### C12-05 · Mover el aviso de sucursal en la pantalla de Miami — ⏳ **ABIERTA, la cierra él**

> *"Tal vez moverlo… me voy a hablar con el muchacho de Miami, porque ellos
> cuando escanean voltean a ver esto."*

Primero pregunta él dónde miran los que escanean.

### C12-06 · Una base de terceros — ⏳ **DIFERIDA**

> *"Ese pues a futuro lo vamos a arreglar… ponerle una base de terceros.
> Todavía solo tenemos la base normal de nosotros, no de un tercero."*

### C12-07 · «Ya recibido en Miami, no debemos poder cambiarla» — ⏳ **HAY QUE PREGUNTARLE**

> *"Ahora, esta información al ya estar recibido en Miami, nosotros no debemos de
> poderla cambiar."*

Lo dijo de pasada y justo antes de otra cosa. Del transcript no se saca **qué**
información ni **quién** no debería poder cambiarla — se le pregunta antes de
tocar nada.

### C12-08 · Data vieja en staging — 🧹 **es de operación, no de código**

> *"Tenés todos los paquetes viejos ahí… la mitad de la información no sirve, es
> data dañada, hay que borrarlo."*

Jorge ya limpió su base local y dijo en la llamada que se le olvidó correrlo en
staging.

---

## Conversación 13 (2026-08-18) — «Retener en Miami», un solo control

Jorge, mirando `/pre_alertas/new` en staging:

> *"Retener en Miami debería comportarse igual que el de etiquetar y entrega
> personal, debería ser el mismo componente, reemplazá el de pre-alerta."*

### C13-01 · El control, escrito una sola vez — ✅ **ARREGLADO (PR-C7.27)**

Al ir a buscar ese componente para reusarlo **no existía**. Había cuatro
pantallas y cuatro respuestas distintas:

| Pantalla | Qué tenía |
|---|---|
| `/etiquetar` | El bloque completo — casilla, modal, motivos y nota |
| `/paquetes` (form) | **Una copia**, ya divergida: consultaba `MotivoRetencion` **adentro de la vista**, y los rótulos y los botones no eran los mismos |
| `/entrega_personal` | **Nada**, aunque su controller carga los motivos y permite `retener_miami` y `motivo_retencion_ids` desde siempre. Cableado muerto |
| `/pre_alertas` | Solo la casilla, y **solo al crear** — la pantalla de editar no la mostraba, así que marcarla por error era irreversible |

Ahora es un `RetenerMiamiComponent` que rendericen las cinco (la pre-alerta lo
pinta dos veces: la tarjeta de crear y la fila de editar), con lint.

**Dónde se guardan los motivos de una pre-alerta: en el paquete esperado**, que
ya tiene esas columnas. `C11-02` había decidido lo contrario —*"va la bandera,
sin motivos: el motivo se sabe cuando el paquete llega"*— y la razón real era
evitar una tabla de join. No hacía falta ninguna.

> ⚠️ **Los motivos no son columnas de `pre_alerta_paquetes` a propósito**, así que
> el dirty tracking de Rails no los ve: `sync_paquete_esperado` necesita una
> bandera propia. Sin ella, editar una pre-alerta cambiando **solo** los motivos
> no sincronizaba nada, en silencio.

### C13-02 · El escaneo ya no borra la retención — ✅ **ARREGLADO (PR-C7.27)**

Venía anotado desde `C11-02` y dejó de ser opcional al entrar los motivos: si el
escaneo apaga la bandera, se los lleva por delante.

Se marca **en la pantalla** y no se fuerza desde el servidor: el que recibe tiene
que poder desmarcarlo si al ver el bulto decide que no. Es la misma forma que
Yusef eligió para el aviso del secundario en `C12-04` — *"lo va a retener, o lo
va a enviar así"*.

De la misma familia: **desmarcar la retención se lleva sus motivos**. Quedaba un
paquete sin retención y con «contenido perecedero» colgado, que es el mismo dato
falso que dejaba el prepago antes de que su concern limpiara la rama `false`.
Nunca sobre un paquete en estado `retenido`, que es **otra cosa** —un paso del
pipeline— y ahí el motivo es obligatorio.

### C13-03 · El portal del cliente **no** lleva el control — decisión, no olvido

Retener es una acción operativa de Miami y los motivos son de ellos («paquete
dañado», «contenido perecedero»). Yusef lo pidió para la pre-alerta de **admin**
(`C11-02`). Queda fijado en el lint para que nadie lo empareje después creyendo
que falta.

---

## Conversación 14 (2026-08-19) — dos llamadas: /etiquetar y los accesos

31 minutos probando `/etiquetar` con la pantalla compartida, y 13 más sobre los
clientes. Transcritas con `whisper small`.

**Lo que confirmó de lo del día**, reproduciéndolo en vivo: la franjita de
«Actualizando» que no se iba y el modal que reaparecía — *"ahí es donde está todo
el mejengue"*. Los dos ya estaban arreglados (`PR-C7.28`, `PR-C7.29`).

> ⚠️ **`PR-C7.29` quedó corto.** Excluía *la fila* y no *el envío*, así que al
> actualizar **una caja de un split** las hermanas —que comparten el tracking—
> seguían disparando el modal. Jorge lo volvió a ver el 21-ago: *"actualizar no
> está aún al 100"*. Completado en `PR-C7.35`. La prueba de entonces usaba un
> paquete de una sola caja, y por eso lo dio por bueno.

### C14-01 · El `1 de N` — ✏️ se corrigió solo

Ver la nota agregada a `A7-21`. Su regla original valía para el **empaque**;
etiquetar es otra cosa porque ahí la cantidad se sabe antes de imprimir.

### C14-02 · Los avisos que nadie lee — ✅ **ARREGLADO (PR-C7.31)**

Lo repitió tres veces, señalando la franja de contexto:

> *"No me da la información, **aquí necesitamos un modal**."*
> *"Estas informaciones **ellos no las leen**. Esto no lo leen, esto no lo van a
> leer, olvídate."*
> *"No te voy a mentir, Jorge: **a puro huevos leen esto**."*

Digitan de 500 a 1.000 paquetes al día mirando la pistola. Retención, tarea y
nota pasan a **un modal cada uno**, con su propia respuesta —retenido / se hizo /
leída— y solo los que el paquete tiene.

> **Uno por cosa y no uno con todo** lo discutieron ahí mismo: él pidió uno solo,
> Jorge argumentó que cada uno necesita su respuesta, y él aceptó — *"tenés
> razón, hacerlo así si querés"*.

De paso salieron dos: las **notas del grupo** nunca se mostraban —*"aquí están
las notas del grupo y no sale"*— y el renglón de la pre-alerta casi nunca se
encontraba, así que **las instrucciones que escribe el cliente se perdían
siempre**.

### C14-03 · El aviso de bolsa del default — ✅ **ARREGLADO (PR-C7.32)**

> *"Esa de San Pedro Sula hay que eliminarlo, porque es el default."*
> *"El cerebro trabaja en default. Cuando querés que haga una cosa diferente al
> default, tenés que ponerle la nota que es diferente."*

El 80% de la carga se queda en San Pedro: un aviso que sale siempre deja de
leerse, y con él el del día que dice Tegucigalpa. Cuál es la de por defecto es
una columna editable desde `/sucursales`, no una constante.

Pidió además **color por sucursal** cuando abran más — *"el cerebro hasta el
color asocia"*. Entra cuando exista la tercera.

### C14-04 · Los tres bugs de actualizar — ✅ **ARREGLADO (PR-C7.30)**

Los reprodujo en vivo: la cantidad de etiquetas que se perdía (*"le di cinco y se
quedó con las primeras tres"*), el cambio de servicio que solo tocaba una caja
(*"debería de cambiar todas"*) y que actualizar un paquete de otro tipo de envío
no avisara nada.

### C14-05 · El acceso del cliente — ✅ **ARREGLADO (PR-C7.33 + PR-C7.37)**

> ⚠️ **`PR-C7.33` quedó corto: dejó el modelo y no la pantalla.** Auditando el
> audio contra el código el 25-ago salieron dos cosas que se habían dado por
> hechas y no lo estaban:
>
> 1. **Un cliente creado por el admin no podía entrar nunca.** `cliente_params`
>    no permitía `:password`, el formulario no tenía campo de clave y
>    `PasswordsController` era solo de `User`. Nacía con `password_digest` nulo,
>    le salía "contraseña incorrecta" para siempre, y "olvidé mi contraseña" le
>    contestaba en silencio. Si además intentaba registrarse solo en `/registro`,
>    la unicidad del correo lo rebotaba. Era exactamente lo que él estaba
>    describiendo —*"yo no le puedo crear una cuenta aquí"*— y se leyó como el
>    caso de los dos correos.
> 2. **Entrar con el código estaba en el modelo pero la pantalla no lo dejaba.**
>    `Cliente.autenticar` acepta las dos llaves, pero el campo del login era un
>    `email_field` con `required`: el navegador rechaza `C2867` antes de enviar.
>    Los 15 tests pasaban porque postean directo al controller, y no había ningún
>    system test del login.
>
> Completado en `PR-C7.37`: la clave se pone y se cambia desde la ficha, el link
> de recuperación funciona para cliente —por correo **y** por código— y el campo
> del login dejó de ser `type="email"`. Lo de `/registro` se cerró en `PR-C7.38`.
> **Queda abierto** que la ficha todavía no muestra `rtn` ni la sucursal de retiro.

> *"Falta el sistema de usuario… lo del acceso de ellos."*
> *"¿Cuál es la cuenta de acceso de él? Y cambiarle la clave por si se le olvidó."*

El cliente ya podía entrar; lo que no existía era **dónde administrarlo**. El caso
que mostró: una clienta con **dos correos** a la que no le pueden crear cuenta,
porque el correo es la llave.

**Entran con el código de casillero o con el correo.** Él lo pidió dos veces —*"es
que mi correo está lleno"*, *"es que yo no tengo correo"*— y Jorge argumentó que
hoy es por correo y es lo que funciona. Quedaron en las dos.

> `clientes.codigo` tiene índice único; `email` **no** —la unicidad la pone solo
> el modelo, o sea que no alcanza a los importados—. Por eso el código es el
> camino que no miente cuando hay correos repetidos.

Y **cortar el acceso no es dar de baja al cliente**: son dos banderas distintas.

### C14-06 · El nombre y el RTN — ✅ **ARREGLADO (PR-C7.33 + PR-C7.38)**

> ⚠️ **La regla llegó a una pantalla y no a la gemela.** `PR-C7.33` la puso en
> `/clientes` y se olvidó de `/registro` —pública, sin autenticar y linkeada
> desde el login—, así que ahí un "Jorge Padilla" pasaba tranquilo. Y los tests
> de esa pantalla usaban nombres de dos palabras **afirmando que se guardaban**:
> congelaban el agujero en vez de avisarlo.
>
> Tampoco había test de la mitad que enforza al editar —solo del caso de *no*
> tocar el nombre—, así que borrar la línea del `#update` dejaba la suite en
> verde.
>
> Cerrado en `PR-C7.38`, con un lint (`test/lint/regla_del_nombre_test.rb`) que
> falla cuando aparece **una tercera pantalla** que construye clientes sin
> encender la bandera. Es el bug recurrente del repo y ahora tiene trinquete.

> *"Tiene que poner mínimo **tres ítems**… por lo menos Jorge y dos apellidos."*
> *"Imaginate cuántos Jorge Padilla hay."*

Es una regla **de la pantalla donde alguien teclea**, no del modelo entero: hay
9.000 clientes importados con dos palabras y una validación a secas trabaría la
migración que sigue pendiente. Al editar, solo si el nombre de verdad cambia.

`rtn` al lado de `identidad`, los dos opcionales — *"eso se va actualizando
cuando ellos van pidiendo factura"*.

### C14-07 · La ficha del paquete y su historial — ⏳ **DIFERIDO por Jorge**

> *"Esta parte del historial de cambios me le quita lo bonito."*

Y la respuesta de Jorge, que es la que manda acá: *"que no te estrese eso hasta
que lleguemos a servicio al cliente, porque ellos son los que van a leer eso"*.

### C14-08 · Migrar los 9.000 clientes del sistema viejo — ⏳ **ABIERTA**

> **Jorge:** *"Lo que más me preocupa es mover los clientes."*
> **Yusef:** *"Yo no tengo cómo este chavo Roger; él hizo tablas y relaciones,
> eso es lo que yo tengo."*

Sin las tablas del sistema viejo no hay nada que planear.

---

## Conversación 15 (2026-08-20) — las reglas del servicio, iguales en las dos pantallas

Jorge, comparando `/pre_alertas/new` con el portal del cliente:

> *"El área de pre-alerta para los admin y clientes es muy diferente; faltan las
> reglas de servicio, que son importantísimas, con respecto a si se puede con
> reempaque y consolidación. Revisá la parte de cliente y aplicale las reglas al
> admin."*

### C15-01 · Admin podía grabar lo que el portal hace imposible — 🐛 ✅ **ARREGLADO (PR-C7.34)**

Las reglas son tres columnas de `tipo_envios`, y el portal las respeta las tres:

| Regla | Portal | Admin (antes) |
|---|---|---|
| `con_reempaque` | sale del servicio | casilla libre |
| `consolidable` | el paso 2 **no existe** si no lo es | casilla libre |
| `max_paquetes_por_accion` | lo dice la tarjeta del servicio | no lo decía |

O sea que admin podía crear una **CKA marcada «con reempaque» y «consolidada»**,
y CKA ni reempaca ni consolida. El modelo tampoco lo impedía: solo cubría el
tercero.

> ⚠️ **Ya había dos fuentes para el mismo hecho, y no coincidían.**
> `PreAlerta#tipo_envio_descripcion` decía «con Reempaque» leyendo el flag **del
> servicio**, mientras el badge «R» del listado leía el **de la fila**. Podían
> decir cosas distintas del mismo envío. Hasta las fixtures traían la
> contradicción: `con_reempaque: false` sobre servicios que sí reempacan.

**Decisión de Jorge**: `con_reempaque` pasa a ser **derivado y no editable** —sale
del servicio, como en el portal— y las pre-alertas viejas que se contradigan se
corrigen con una migración que informa cuáles tocó.

Las reglas viven en el **modelo**, no en la vista: una regla que vive en una
pantalla es una regla que la otra no tiene, que es exactamente cómo se llegó acá.
Y el campo derivado sale del `permit` de los dos controllers — aceptarlo por
parámetro es la puerta por la que vuelve la contradicción.

> **El admin no lleva el wizard**, y eso no cambió: sigue vigente lo decidido el
> 2026-08-12 —*"los controles NO cambian… el wizard de 3 pasos del portal ya se
> había descartado para admin"*—. Lo que se emparejó son **las reglas**, no los
> pasos.

De paso: la pantalla de alta nunca le pasaba el límite de paquetes al
`pre-alerta-editor` —que sabe deshabilitar «Agregar Paquete» desde siempre—,
así que el operario llenaba todo y el servidor lo rechazaba después. `/edit` sí
lo pasaba: la gemela otra vez.
