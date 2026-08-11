# Las tres opciones del sonido de error, para que Yusef elija una.
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
    }
  ].freeze

  IDS = VARIANTES.map { |v| v[:id] }.freeze
  DEFAULT = IDS.first

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
