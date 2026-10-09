# Los sonidos de error, para mandarle a Yusef

`RP-20` le prometía *"te mandamos tres opciones por WhatsApp para que las
oigas"*. Nunca se hicieron, así que dejó la casilla en blanco — no puede
contestar algo que no recibió. Estos son.

```bash
bin/rails docs:sonidos_wav      # los regenera
afplay error_*.wav              # escuchalos antes de mandarlos
```

| Archivo | Cómo suena |
|---|---|
| `error_alarma.wav` | **El de por defecto desde el 2026-10-08.** Cinco zumbidos ásperos y rápidos (0.42 s) |
| `error_grave.wav` | El de siempre. Un tono bajo de 0.3 s |
| `error_descendente.wav` | Dos tonos que caen (440 → 220). El «respuesta incorrecta» de toda la vida |
| `error_triple.wav` | Tres pulsos cortos. El de «tipo de envío distinto» en el manifiesto |
| `error_agudo.wav` | Un pito alto (1500 Hz). El de «va a otra sucursal» en el manifiesto |

**PR-C29.9 · Todos suenan más fuerte y más ásperos que antes.** Jorge, el
2026-10-08: *"el audio de error tiene que ser más cruel, fuerte, molesto,
intenso"*. Cada tono es ahora dos ondas a un semitono, sostenidas y saturadas
(`SonidosDeError::VOZ`): a igual pico, unas 3.4 veces más energía que los
archivos de antes (+10 dB).

## Lo que hay que decirle al mandárselos

**Que también los puede oír en la pantalla.** En `/etiquetar` y en
`/entrega_personal`, botón **Sonidos** → cada uno con su «Escuchar». Ahí es
donde conviene juzgarlos: un sonido de bodega se elige con el ruido de la
bodega de fondo, no en el parlante de un celular.

**Que «dejalo como está» sigue siendo una respuesta.** `error_grave` es el de
siempre y se puede volver a elegir; quien ya lo tenía guardado no cambia de
variante, solo de voz.

## Detalles

Salen de `SonidosDeError::VARIANTES` —la **misma** constante que toca el
navegador—, renderizados por `SonidosWav` en Ruby puro. No hay una versión "de
mentira" para el archivo: hay un test que compara los `.wav` versionados contra
lo que la constante produce hoy, así que si alguien cambia una variante y no
regenera, la suite falla.

Si WhatsApp no toma el `.wav`:

```bash
for f in *.wav; do afconvert -f m4af -d aac "$f"; done
```

Cuando conteste, la respuesta se anota en `docs/05_requerimientos_conversaciones.md`
y el ganador pasa a ser el **default** de `sonido_error_variante` — ahí cambia
para todos, no solo para quien lo eligió en su usuario.
