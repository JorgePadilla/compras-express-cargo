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
- CON REEMPAQUE + SIN CONSOLIDAR:
  - CER - AEREO CON REEMPAQUE SIN CONSOLIDAR
  - CEM - MARITIMO CON REEMPAQUE SIN CONSOLIDAR
  - EXP - AEREO EXPRESS SIN CONSOLIDAR
- (Otras combinaciones generan opciones diferentes: CKA, CKM, etc.)

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

| Código | Significado |
|--------|------------|
| CER | Carga Express Aéreo (con reempaque) |
| CEM | Carga Express Marítimo (con reempaque) |
| CKA | Carga Kilo Aéreo (sin reempaque) |
| CKM | Carga Kilo Marítimo (sin reempaque) |
| EXP | Express (aéreo rápido) |

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
- **Tipo de Envío** (dropdown):
  - Sin Definir (default)
  - CKA - AEREO SIN REEMPAQUE (value=1)
  - CER - AEREO CON REEMPAQUE (value=2)
  - CKM - MARITIMO SIN REEMPAQUE (value=3)
  - CEM - MARITIMO CON REEMPAQUE (value=4)
  - EXP - AEREO EXPRESS (value=5)
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
- Cobro mínimo SPS: L200.00, Tegucigalpa: L200.00 (ISV incluido)
- LÍNEA 2: AEREO CKA

**EXP - AÉREO EXPRESS:**
- $8.00 por libra o tamaño + ISV
- 3 a 7 días hábiles
- Cobro mínimo SPS y Tegucigalpa: $14.95 ISV incluido
- Vuela una vez a la semana los viernes a las 10:00 AM
- LÍNEA 2: EXPRESS

**CEM - MARÍTIMO CON REEMPAQUE Y OPCIÓN A CONSOLIDAR:**
- $2.50 por libra o tamaño + ISV
- 14 a 17 días hábiles
- Mínimo 8 libras
- LÍNEA 2: REEMPAQUE MARITIMO

**CKM - MARÍTIMO SIN REEMPAQUE NI CONSOLIDADO:**
- SPS: $1.90 por libra o tamaño + ISV
- 14 a 17 días hábiles
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
Formulario de etiquetado de paquetes en Miami (vista operador):

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
- **Tabla columnas:** Fecha, No. Manifiesto, Trackings, Carrier (PRONTO CARGO, SERCARGO, GENESIS), Estado (ENVIADO, ADUANA), Tipo (AEREO, AEREO EXPRESS, CKM MARITIMO, CKA ESTANDARD), Cantidades, Pesos, Montos

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

| Rol | Descripción probable |
|-----|---------------------|
| **Cliente** | Usuario final, ve sus paquetes, tracking, facturas |
| **Administrador** | Acceso total al sistema |
| **Supervisor de Caja** | Supervisa pagos y cajeros en Honduras |
| **Supervisor de Miami** | Supervisa recepción, pre-alertas, re-empaque en Miami |
| **Supervisor Prefactura** | Supervisa generación de prefacturas |
| **Cajeros** | Procesan pagos de clientes |
| **SAC** (Servicio al Cliente) | Atención al cliente, consultas, reclamos |
| **Entrega y Despacho** | Gestiona entregas finales al cliente |

### Pendiente por definir en conversación:
- [ ] Permisos específicos por rol (qué módulos ve cada uno)
- [ ] Flujo de creación de usuarios (quién crea a quién)
- [ ] Autenticación (email/password, 2FA?)
- [ ] Manejo de sesiones y logout
- [ ] Roles múltiples por usuario? (ej: un supervisor que también es cajero)
- [ ] Ubicación por usuario (Miami vs Honduras)

---

## Próximos Pasos

1. **Conversación 2:** Login, Logout, Creación de usuarios y roles — por documentar
2. **Conversación 3:** Pendiente — visita al cliente
3. **Conversación 4:** Pendiente — visita al cliente
4. Después de las 4 conversaciones: crear plan de implementación completo por módulo
