# Entregables para el cliente

Documentos que se le mandan a Yusef para revisar o llenar. Están versionados
para tenerlos a mano sin regenerarlos, pero **se generan desde código** — así
el binario nunca queda huérfano de su fuente ni se desincroniza de la doc.

```bash
bin/rails docs:entregables      # regenera ambos
bin/rails docs:resumen_pdf
bin/rails docs:preguntas_xlsx
```

Fuente: `lib/tasks/docs.rake`.

| Archivo | Qué es |
|---|---|
| `resumen_para_yusef.pdf` | Resumen en lenguaje de negocio de lo construido en las Fases 10 y 11, los errores de facturación que se encontraron, y lo que falta que él decida. 5 páginas. |
| `preguntas_para_yusef.xlsx` | No es un cuestionario: es una **plantilla que llena y devuelve**. La hoja 2 es la matriz de tarifas (servicio × categoría × escalón) pre-cargada con lo que hay hoy — es lo único que bloquea sembrar los precios reales. |

## Cuándo regenerarlos

Cuando cambie lo que documentan. En particular:

- El PDF toma su contenido de `docs/05` (Conversaciones 4 y 5) y `docs/06`
  (Fases 10 a 12). Si se responde una de las preguntas pendientes o se cierra
  un frente, hay que actualizarlo.
- El Excel **lee la base de datos** (`TipoEnvio`, `CategoriaPrecio`) para
  pre-llenar la matriz, así que cambia solo al regenerarlo si se agregan
  servicios o categorías.

> Ojo: si Yusef ya devolvió el Excel con sus respuestas, **no lo pises
> regenerando** — guardá su versión aparte antes de correr la tarea.
