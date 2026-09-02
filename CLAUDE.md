# CEC — cómo se trabaja en este repo

Sistema de courier Miami → Honduras. Reemplaza al legacy ASP.NET de
`cec.rsahn.com`. Rails 8 + Hotwire + Tailwind 4 + PostgreSQL 17.

El cliente es **Yusef**. Casi todo lo que se construye sale de una conversación
grabada con él, y esa conversación está transcrita y documentada. Antes de
diseñar algo, buscalo en `docs/05_requerimientos_conversaciones.md`.

## Dónde vive cada cosa

| Qué | Dónde |
|---|---|
| Requerimientos, con la cita textual del cliente | `docs/05_requerimientos_conversaciones.md` |
| Estado de las fases y series de PR | `docs/06_fases_implementacion.md` |
| Paleta y componentes | `docs/07_design_system.md` |
| Índice de toda la doc | `docs/README.md` |
| Entregables para el cliente | `docs/entregables/` |

**Los entregables se generan desde código** (`lib/tasks/docs.rake`,
`lib/servicios_pdf.rb`, `lib/procesos_pdf.rb`, `lib/pdf_entregable.rb`). Nunca
editar el PDF ni el XLSX a mano. Y si Yusef ya devolvió uno contestado, **no se
pisa regenerando** — se guarda su versión aparte primero.

## Commits

Conventional Commits **en español**, con el id del PR entre paréntesis al final
del subject:

```
feat(pre-alerta): admin se ve como el portal, y no puede volver a separarse (PR-C6.46)
fix(sonidos): el modal probaba sonidos que no eran los que suenan
docs(conversacion-6): reconcilia las tablas de estado con el audio 4
refactor(paquetes/show): los botones de verdad pasan a ButtonComponent (PR-BTN.5)
```

El subject es una frase que se lee, no un imperativo seco. El scope es el módulo.

**El cuerpo importa más que el subject.** Va largo y estructurado: arranca por el
**porqué** —muchas veces citando lo que pidió Jorge o Yusef—, después el qué, y
cierra con el conteo de la suite (`Suite: 1879 runs, 0 failures.`). Si el PR
cambia una decisión anterior, se dice cuál y por qué.

## Ramas y PRs

- Rama: `{tipo}/{descripcion-en-kebab-case}` — `feat/prealerta-admin-como-el-portal`,
  `fix/aviso-tarifas-huerfanas`, `docs/reconciliar-audio-4`. Sin número de issue.
- **Todo va contra `staging`.** `staging → main` promueve a producción.
- El título del PR es el mismo subject del commit.
- CI corre en `.github/workflows/`, incluido un review automático de Gemini.

## Lo que hacen cumplir los tests

No son convenciones escritas: si te salís, el test falla.

- `test/lint/banned_colors_test.rb` — la paleta de `docs/07`.
- `test/lint/autocomplete_teclado_test.rb` — que las vistas con autocomplete le
  pasen el `keydown` al controller.
- `test/lib/procesos_pdf_test.rb` — que los diagramas de proceso nombren rutas y
  estados que **existan**. Si construís un módulo que el diagrama daba por
  pendiente, este test avisa que el dibujo quedó viejo.
- `test/lint/botones_con_funcion_test.rb` — entre otras cosas, que «Volver» vaya
  en el slot `with_back` del `PageHeaderComponent` y no entre las acciones:
  atrás es izquierda.

## Series de PR

Cuatro numeraciones conviven. `PR-{fase}.{letra}` y `PR-D{n}.{letra}` se siguen
en `docs/06`; **`PR-C6.{nn}` se sigue en `docs/05`**; `PR-BTN.{n}` es un refactor
transversal que no cuelga de ninguna fase. `RP-{nn}` no son PRs: son las
preguntas al cliente.

## Cosas que se aprendieron a golpes

- **El mismo arreglo suele necesitar dos pantallas.** Admin y portal cliente
  tienen vistas gemelas; el bug recurrente de este repo es arreglar una y no la
  otra. Antes de cerrar, buscá la gemela.
- **Los precios los carga el equipo del cliente**, no el código. En dev hay
  fixtures sembradas encima, así que un número raro suele ser la base de dev, no
  un bug. Verificá con `db:reset` antes de reportar.
- **La plata se toca con cuidado.** Redondeo, escalones, mínimos e ISV están
  documentados en `docs/05`; cambiar uno sin leer la cadena completa cobra mal.
- **Enter no guarda.** En `/etiquetar` la pistola de códigos dispara Enter: Enter
  pasa al siguiente campo, nunca envía el formulario.
