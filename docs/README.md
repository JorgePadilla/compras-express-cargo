# Índice de la documentación

Qué contesta cada archivo y cuál manda cuando dos se contradicen.

## Los vigentes

| Archivo | Contesta | Es la fuente de verdad de |
|---|---|---|
| [`05_requerimientos_conversaciones.md`](05_requerimientos_conversaciones.md) | ¿Qué pidió el cliente y con qué palabras? | **Los requerimientos.** 7 conversaciones, los hallazgos `A{n}-{nn}` y las preguntas `RP-{nn}`. También sigue la serie `PR-C6` |
| [`06_fases_implementacion.md`](06_fases_implementacion.md) | ¿En qué fase va el sistema y qué falta? | **El estado de las fases** y las series de PR |
| [`02_modelos_base_datos.md`](02_modelos_base_datos.md) | ¿Cómo está modelada la base? | Junto con `db/structure.sql`, que es el que no miente |
| [`07_design_system.md`](07_design_system.md) | ¿Qué colores, tokens y componentes se usan? | **La paleta.** La imponen tests: `test/lint/banned_colors_test.rb` |
| [`03_deployment_render.md`](03_deployment_render.md) | ¿Cómo y a dónde se despliega? | Los ambientes de Render y el pipeline |
| [`staging_credentials.md`](staging_credentials.md) | ¿Con qué usuario pruebo en staging? | Los usuarios de prueba |
| [`approved/pre_alerta_v4.docx`](approved/) | ¿Cuál es el flujo de pre-alerta aprobado? | **Los 5 servicios y las reglas de pre-alerta.** Ante conflicto, prevalece v4 |
| [`entregables/`](entregables/README.md) | ¿Qué se le mandó al cliente? | Los PDFs y el Excel que se le entregan. **Se generan desde código** |

## Los históricos

[`historico/`](historico/) tiene los documentos de marzo 2026. Describen el
**plan original**, no el sistema de hoy — se conservan por el registro de las
decisiones de arranque, pero **no se usan como referencia**.

| Archivo | Lo reemplaza |
|---|---|
| `historico/01_arquitectura_general.md` | Este README + `06_fases_implementacion.md` |
| `historico/04_diseno_responsive.md` | `07_design_system.md` |
| `historico/database_diagram.md` | `02_modelos_base_datos.md` + `db/structure.sql` |

## Cómo leerlos según lo que busques

- **"¿Qué falta por hacer?"** → `05`, sección *Próximos Pasos*, y el punch-list
  de la última conversación. La tabla de fases de `06` va más lenta.
- **"¿Por qué el sistema hace esto?"** → `05`, buscá el `A{n}-{nn}`. Casi todo
  tiene la cita textual del cliente al lado.
- **"¿Esto ya se preguntó?"** → `05`, las tablas `RP-{nn}`.
- **"¿De qué color va este botón?"** → `07`. Y si te equivocás, el lint te avisa.
- **"¿Cuánto se cobra?"** → la base de datos (`Tarifa`, `TipoEnvio`), no la
  documentación. `bin/rails docs:servicios_pdf` la imprime.

## Convenciones

Cómo se escriben los commits, las ramas y los PRs está en
[`../CLAUDE.md`](../CLAUDE.md).
