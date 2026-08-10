# Entregables para el cliente

Documentos que se le mandan a Yusef para revisar o llenar. Están versionados
para tenerlos a mano sin regenerarlos, pero **se generan desde código** — así
el binario nunca queda huérfano de su fuente ni se desincroniza de la doc.

```bash
bin/rails docs:entregables      # regenera los cuatro de docs.rake
bin/rails docs:resumen_pdf
bin/rails docs:historia_pdf
bin/rails docs:preguntas_xlsx
bin/rails docs:preguntas_pdf
bin/rails docs:servicios_pdf    # estos dos van aparte
bin/rails docs:procesos_pdf
```

Fuente: `lib/tasks/docs.rake`, `lib/servicios_pdf.rb` y `lib/procesos_pdf.rb`.
El estilo compartido —las constantes, las tablas, la casilla que se marca a
mano— vive en `lib/pdf_entregable.rb`; las cajas, flechas y bifurcaciones de
los diagramas, en `lib/pdf_diagrama.rb`.

| Archivo | Qué es |
|---|---|
| `resumen_para_yusef.pdf` | Resumen en lenguaje de negocio de lo construido en las Fases 10 y 11, los errores de facturación que se encontraron, y lo que falta que él decida. 5 páginas. |
| `historia_y_reglas.pdf` | El documento largo: el recorrido de un paquete, **todas las reglas de negocio que el sistema aplica**, la historia por etapas y las decisiones tomadas. La parte 2 es la que hay que revisar — si una regla está mal, se cobra mal. 7 páginas. |
| `preguntas_para_yusef.pdf` | Las 23 preguntas para contestar **a mano**: casilla dibujada y renglones. Es el formato que volvió contestado y del que salieron los requerimientos `RP-01`…`RP-23`. |
| `servicios_para_yusef.pdf` | Los cinco servicios: una comparativa, una ficha por cada uno con su escalera de precios y su mínimo, cómo se calcula lo que se cobra, y por dónde pasa un paquete. Los números **salen de la base**, no de la documentación, y donde los dos no coinciden va la pregunta con su casilla (`RP-24`…`RP-29`). 9 páginas. |
| `procesos_para_yusef.pdf` | Los diagramas de proceso: el camino que recorre un paquete desde la pre-alerta hasta la entrega, más los ocho desvíos (Entrega Personal, consolidación, reempaque, recolecta, retención, cambio de servicio, salidas del camino, notas). Lo que contesta es **hasta dónde llega lo construido**: los pasos sin pantalla van con borde punteado. Preguntas `RP-30`…`RP-34`. 12 páginas. |
| `preguntas_para_yusef.xlsx` | **Hoja 1:** las 12 preguntas abiertas, ordenadas por urgencia — las tres primeras son las que hoy hacen que el sistema cobre distinto de lo que él quiere. **Hoja 2:** todas las tarifas cargadas, leídas de la base. **Hoja 3:** los 11 campos de la etiqueta. **Hoja 4:** los cargos que no son flete, con la moneda que falta definir. |

## Cuándo regenerarlos

Cuando cambie lo que documentan. En particular:

- El PDF toma su contenido de `docs/05` (Conversaciones 4 y 5) y `docs/06`
  (Fases 10 a 12). Si se responde una de las preguntas pendientes o se cierra
  un frente, hay que actualizarlo.
- La hoja 2 del Excel y la tabla de servicios del PDF largo **leen la base de
  datos** (`Tarifa`, `TipoEnvio`), así que un cambio de precios se refleja solo
  al regenerarlos. Corré `bin/rails tarifas:sembrar_propuesta_2026` antes si
  venías de una base sin sembrar.

> Ojo: si Yusef ya devolvió el Excel o un PDF con sus respuestas, **no lo
> pises regenerando** — guardá su versión aparte antes de correr la tarea.

## Antes de mandar el de servicios

`docs:servicios_pdf` imprime avisos en la consola cuando encuentra algo raro
en los datos: un servicio activo que no es de los cinco, uno sin tarifa de
lista, o una tarifa apuntando a una sucursal que ya no existe. **Esos avisos
son para vos, no van al PDF** — pero conviene resolverlos antes de mandarlo,
porque el documento muestra lo que la base dice.

## El de procesos se prueba contra el sistema

Un diagrama que apunta a una pantalla que ya no existe es peor que no tenerlo,
así que los flujos de `lib/procesos_pdf.rb` están escritos **como datos** y
`test/lib/procesos_pdf_test.rb` los confronta contra el código: cada ruta que
el dibujo nombra tiene que existir en `routes`, cada estado en `Paquete.estados`,
y los pasos marcados como pendientes tienen que seguir sin tener quien los
asigne. Si alguien construye el módulo de empaque, el test avisa que el
diagrama quedó viejo.
