# Las opciones del sonido de error, para que Yusef elija una. Eran tres
# (`RP-20`); la cuarta, aguda, la pidió él el 2026-09-05 (`C25-10`).
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
  # El orden importa: `grave` va primero porque es **el sonido de hoy**. Que la
  # respuesta "no le muevan nada" sea una opción no es cortesía, es honestidad;
  # y así cambiar el default es una decisión deliberada y no un descuido.
  VARIANTES = [
    {
      id: "grave",
      nombre: "Grave",
      descripcion: "El que suena hoy. Un tono bajo y seco.",
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
    # C25-10 · La cuarta, y la única **aguda**. Las tres de arriba son graves
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
  # nuevos: las cuatro ya pasaron por las reglas de este archivo (no suben, no
  # se parecen a los avisos)—, elegida por el operario en el modal de sonidos.
  # Los defaults son distintos entre sí y del error de siempre (`grave`).
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

  REPETICIONES = 2
  PAUSA_MS = 150

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

  # Solo los tonos que suenan, sin los silencios.
  def self.frecuencias(variante)
    variante[:tonos].map { |t| t[:hz] }.reject(&:zero?)
  end

  def self.duracion_ms(variante)
    variante[:tonos].sum { |t| t[:ms] }
  end
end
