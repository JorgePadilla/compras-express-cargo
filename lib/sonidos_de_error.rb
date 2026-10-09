# Las opciones del sonido de error, para que Yusef elija una. Eran tres
# (`RP-20`); la cuarta, aguda, la pidió él el 2026-09-05 (`C25-10`); la
# quinta, la «alarma», salió de Jorge el 2026-10-08 (`PR-C29.9`).
#
# `RP-20` es deuda nuestra: el cuestionario le prometía "te mandamos tres
# opciones por WhatsApp para que las oigas" y esas tres nunca se hicieron. Dejó
# la casilla en blanco porque no puede contestar algo que no recibió.
#
# ── Por qué esto es una constante de Ruby y no dos definiciones ────────────
#
# Las variantes las consumen dos cosas: el navegador, que las toca con
# osciladores, y `SonidosWav`, que las renderea a archivo para mandárselas por
# WhatsApp. Definirlas dos veces es garantizar que diverjan — es el bug que más
# veces mordió a este repo.
#
# Como importmap no tiene build step, el JS no puede leer un archivo del disco:
# la vista serializa esta constante a JSON y se la pasa en un data attribute.
# Hay un test que compara lo que la vista emite contra lo que hay acá.
module SonidosDeError
  # `hz` cero es silencio: sirve para separar pulsos sin inventar otra clave.
  #
  # El orden importa: la primera es **el default**. Fue `grave` —el sonido de
  # siempre— hasta el 2026-10-08, y que «no le muevan nada» fuera una opción
  # era honestidad: cambiar el default tenía que ser una decisión, no un
  # descuido.
  #
  # PR-C29.9 · Y la decisión llegó. Jorge, probando el manifiesto con Yusef:
  # *"el audio de error creo que tiene que ser **más cruel, fuerte, molesto,
  # intenso**"*. Ya lo había dicho Yusef el mismo día: *"algo como que de
  # verdad te llama, que está equivocada, que no va ahí"*, y en C25-10 desde
  # la mesa de empaque: *"está muy suavecito"*. Va primera la «alarma»: cinco
  # zumbidos iguales y rápidos, que es como suena un error que no se puede
  # ignorar. `grave` sigue estando para quien la elija.
  #
  # Los usuarios que ya existen tienen `grave` **guardado** en la columna (es
  # NOT NULL con default), y no se les pisa: no hay forma de distinguir a quien
  # la eligió de quien nunca abrió el modal. Lo que sí les llega a todos es la
  # voz nueva (`VOZ`, abajo), que vuelve áspera cualquier variante.
  VARIANTES = [
    {
      id: "alarma",
      nombre: "Alarma",
      descripcion: "Cinco zumbidos ásperos y rápidos. El más molesto: imposible de ignorar.",
      tonos: [ { hz: 400, ms: 60 }, { hz: 0, ms: 30 },
               { hz: 400, ms: 60 }, { hz: 0, ms: 30 },
               { hz: 400, ms: 60 }, { hz: 0, ms: 30 },
               { hz: 400, ms: 60 }, { hz: 0, ms: 30 },
               { hz: 400, ms: 60 } ]
    },
    {
      id: "grave",
      nombre: "Grave",
      descripcion: "El de siempre. Un tono bajo, largo y áspero.",
      tonos: [ { hz: 200, ms: 300 } ]
    },
    {
      id: "descendente",
      nombre: "Descendente",
      descripcion: "Dos tonos que caen. El «respuesta incorrecta» de toda la vida.",
      tonos: [ { hz: 440, ms: 120 }, { hz: 220, ms: 180 } ]
    },
    {
      id: "triple",
      nombre: "Triple",
      descripcion: "Tres pulsos cortos. Suena a alarma: el más difícil de ignorar.",
      tonos: [ { hz: 320, ms: 80 }, { hz: 0, ms: 60 },
               { hz: 320, ms: 80 }, { hz: 0, ms: 60 },
               { hz: 320, ms: 120 } ]
    },
    # C25-10 · La única **aguda**. Las de arriba son graves
    # (200 a 440 Hz) y Yusef, desde la mesa de empaque con la computadora
    # lejos, pidió lo contrario: *"tiene que ser más como **pit** que tú… está
    # muy suavecito"*. Un tono alto y plano: no sube (la regla de acá), dura
    # un cuarto de segundo, y se separa de los graves de oído.
    {
      id: "agudo",
      nombre: "Agudo",
      descripcion: "Un pito alto y seco. Para cuando la computadora está lejos de la mesa.",
      tonos: [ { hz: 1500, ms: 250 } ]
    }
  ].freeze

  IDS = VARIANTES.map { |v| v[:id] }.freeze
  DEFAULT = IDS.first

  # C29-08 · **Un sonido por error**, para los dos que frenan al escanear el
  # manifiesto. Yusef, 2026-10-08:
  #
  #   > "Si el tipo de envío es el error, tiene que tirar un sonido de una
  #   >  forma. Si la sucursal es el error, tiene que tirar un sonido de error,
  #   >  pero de otro tono… Cada error tiene que tener un tono distinto para
  #   >  que ellos sepan."
  #   > "Algo como que de verdad te llama, que está equivocada, que no va ahí."
  #
  # Cada uno toca una de las `VARIANTES` de arriba —no se inventan tonos
  # nuevos: todas pasaron por las reglas de este archivo (no suben, no se
  # parecen a los avisos)—, elegida por el operario en el modal de sonidos.
  # Los defaults son distintos entre sí y del error de siempre (`DEFAULT`).
  #
  # Y **suenan dos veces**: el pip de un error cualquiera es un pip, y éstos
  # tienen que llamar. `REPETICIONES` y `PAUSA_MS` los lee el JS por el mismo
  # data attribute que las variantes.
  MOTIVOS = [
    { id: "tipo_distinto", accion: "errorTipo", columna: :sonido_error_tipo, default: "triple",
      nombre: "Tipo de envío distinto", ayuda: "Al escanear un paquete de otro servicio que el del manifiesto" },
    { id: "sucursal_distinta", accion: "errorSucursal", columna: :sonido_error_sucursal, default: "agudo",
      nombre: "Va a otra sucursal", ayuda: "Al escanear un paquete que retira en otra sucursal que la del manifiesto" }
  ].freeze

  # PR-C29.9 · **Tres** veces, no dos. Estos dos errores frenan el escaneo y
  # *"generan gasto"* (C28-04): un paquete de otro servicio o de otra sucursal
  # que se cuela viaja mal. Jorge pidió el error *"más intenso"*; un tercer
  # golpe es lo que separa «algo pasó» de «pará». Son los únicos que
  # repiten, y son raros: el pip de cada escaneo bueno no cambia.
  REPETICIONES = 3
  PAUSA_MS = 150

  # PR-C29.9 · **La voz del error**: con qué timbre suena cualquier variante.
  #
  # Antes era una onda cuadrada sola cuya ganancia empezaba a caer desde la
  # primera muestra (`exponentialRampToValueAtTime` a 0.001): cada tono era un
  # «tic» que se apagaba antes de llegar a sonar, y el tope de ganancia (0.9 ×
  # volumen) lo dejaba en 0.54 con el volumen por defecto. Jorge: *"más cruel,
  # fuerte, molesto, intenso"*.
  #
  # Ahora:
  #   · **dos ondas a un semitono** —cuadrada en la nota, sierra un semitono
  #     arriba (`segunda`)—: el choque de dos notas pegadas es el zumbido de
  #     un buzzer, el intervalo más molesto que hay;
  #   · **sostenida**: sube en `ataque_ms`, se queda arriba todo el tono y cae
  #     en los últimos `caida_ms`. Suena el tono entero, no su primer instante;
  #   · **saturada** con una curva `tanh` de ganancia `saturacion`: aplasta la
  #     onda contra el techo, que es lo que la hace sonar fuerte al mismo
  #     volumen, y le agrega la aspereza de un parlante al límite.
  #
  # Es una constante y no tres números en el JS por la misma razón que las
  # variantes: `SonidosWav` renderea los archivos de WhatsApp **con la misma
  # cuenta**, y la vista se la pasa al navegador en un data attribute. Por eso
  # la saturación es una curva (`WaveShaperNode`) y no un compresor: una curva
  # se escribe igual en Ruby y en el navegador, un compresor no.
  #
  # Es solo de los errores: `success`, `notify`, `alert` y `completo` siguen
  # con su tono limpio. Un «todo bien» áspero dejaría de sonar a «todo bien».
  VOZ = {
    segunda: 1.0595,   # un semitono: 2^(1/12)
    mezcla: 0.6,       # cuánto aporta cada onda antes de saturar
    saturacion: 3.0,   # la `k` de tanh(k·x)/tanh(k)
    ataque_ms: 5,
    caida_ms: 15
  }.freeze

  def self.motivo(id)
    MOTIVOS.find { |m| m[:id] == id }
  end

  # Lo que ya suena en las pantallas, para que ninguna variante de error se le
  # parezca. Vive acá y no en el JS porque es lo que el test compara.
  #
  # Las tres suben de tono. Por eso **ninguna variante de error puede subir**:
  # un error que suena como un aviso de «todo bien» no avisa nada.
  YA_TOMADOS = {
    "success" => [ 800 ],
    "notify"  => [ 880, 1320 ],
    "alert"   => [ 600, 900 ]
  }.freeze

  def self.find(id)
    VARIANTES.find { |v| v[:id] == id } || VARIANTES.first
  end

  # La curva de saturación, una muestra por vez. La usan `SonidosWav` y —con
  # los mismos números, vía `VOZ`— el `WaveShaperNode` del navegador. La
  # entrada se recorta a [-1, 1] como hace el `WaveShaperNode` con lo que cae
  # fuera de su curva.
  def self.saturar(x)
    k = VOZ[:saturacion]
    Math.tanh(k * x.clamp(-1.0, 1.0)) / Math.tanh(k)
  end

  # Solo los tonos que suenan, sin los silencios.
  def self.frecuencias(variante)
    variante[:tonos].map { |t| t[:hz] }.reject(&:zero?)
  end

  def self.duracion_ms(variante)
    variante[:tonos].sum { |t| t[:ms] }
  end
end
