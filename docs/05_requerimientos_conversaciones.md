# Requerimientos del Sistema - Conversaciones con el Cliente

Sistema actual: `https://cec.rsahn.com/App/Home`

## Módulos Identificados

| # | Módulo | Conversación | Estado |
|---|--------|-------------|--------|
| 1 | Pre-alertas + Mejoras al sistema actual | Conversación 1 | Documentado abajo |
| 2 | Login, Logout, Usuarios y Roles | Parcial | Roles definidos, conversación detallada pendiente |
| 3 | Por definir (visita al cliente) | Pendiente | Por agendar |
| 4 | Por definir (visita al cliente) | Pendiente | Por agendar |

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
