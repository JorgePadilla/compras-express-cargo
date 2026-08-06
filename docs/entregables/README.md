# Entregables para el cliente

Documentos que se le mandan a Yusef para revisar o llenar. Están versionados
para tenerlos a mano sin regenerarlos, pero **se generan desde código** — así
el binario nunca queda huérfano de su fuente ni se desincroniza de la doc.

```bash
bin/rails docs:entregables      # regenera los tres
bin/rails docs:resumen_pdf
bin/rails docs:historia_pdf
bin/rails docs:preguntas_xlsx
```

Fuente: `lib/tasks/docs.rake`.

| Archivo | Qué es |
|---|---|
| `resumen_para_yusef.pdf` | Resumen en lenguaje de negocio de lo construido en las Fases 10 y 11, los errores de facturación que se encontraron, y lo que falta que él decida. 5 páginas. |
| `historia_y_reglas.pdf` | El documento largo: el recorrido de un paquete, **todas las reglas de negocio que el sistema aplica**, la historia por etapas y las decisiones tomadas. La parte 2 es la que hay que revisar — si una regla está mal, se cobra mal. 7 páginas. |
| `preguntas_para_yusef.xlsx` | Hoja 1: las preguntas abiertas, con su contexto, para que las conteste en la columna amarilla. Hoja 2: **todas las tarifas cargadas, leídas de la base** — lo que el sistema va a cobrar, para que lo confirme. Hoja 3: los 11 campos de la etiqueta, para que marque los imprescindibles. |

## Cuándo regenerarlos

Cuando cambie lo que documentan. En particular:

- El PDF toma su contenido de `docs/05` (Conversaciones 4 y 5) y `docs/06`
  (Fases 10 a 12). Si se responde una de las preguntas pendientes o se cierra
  un frente, hay que actualizarlo.
- La hoja 2 del Excel y la tabla de servicios del PDF largo **leen la base de
  datos** (`Tarifa`, `TipoEnvio`), así que un cambio de precios se refleja solo
  al regenerarlos. Corré `bin/rails tarifas:sembrar_propuesta_2026` antes si
  venías de una base sin sembrar.

> Ojo: si Yusef ya devolvió el Excel con sus respuestas, **no lo pises
> regenerando** — guardá su versión aparte antes de correr la tarea.
