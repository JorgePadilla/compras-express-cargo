# Los sonidos que el modal "Sonidos de escaneo" deja probar.
#
# ── Por qué esto es una constante y no una lista en el ERB ────────────────
#
# La lista estaba escrita a mano en el partial y **se separó de la realidad**:
#
#   · el botón rotulado "Pre-alerta" tocaba `notify`, que en el sistema es el
#     sonido de «este tracking ya existía». El rótulo mentía.
#   · el sonido de pre-alerta de verdad —`speakPreAlerta`, que suma la voz
#     diciendo "pre alerta" arriba del pito— **no tenía botón**. O sea que lo
#     único que no se podía probar era justo lo que más se oye.
#
# Jorge lo agarró de oído: "el modal suena distinto de los reales; los del
# sistema están bien, hay que arreglar los del modal".
#
# Ahora la lista es dato y hay un test que la confronta contra lo que las
# vistas cablean de verdad: agregar un sonido a una pantalla sin agregarle su
# botón acá rompe la suite.
module SonidosDeEscaneo
  # En el orden en que aparecen escaneando, no en el orden en que se
  # programaron: primero lo que suena siempre, al final lo que suena mal.
  BOTONES = [
    { accion: "success", etiqueta: "Guardado",
      ayuda: "Cuando el paquete quedó grabado" },
    { accion: "speakPreAlerta", etiqueta: "Pre-alerta",
      ayuda: "El pito y la voz. Es el sonido completo, no solo el pito" },
    { accion: "notify", etiqueta: "Ya existía",
      ayuda: "El tracking estaba repetido. También suena al abrirse un aviso" },
    { accion: "alert", etiqueta: "Notas del cliente",
      ayuda: "El cliente tiene notas que hay que leer" },
    { accion: "error", etiqueta: "Error",
      ayuda: "Toca la opción elegida arriba" }
  ].freeze

  ACCIONES = BOTONES.map { |b| b[:accion] }.freeze

  # `submitEnd` se cablea en las vistas pero **no es un sonido**: es el que
  # escucha a Turbo y termina llamando a `error`. Darle un botón sería ofrecer
  # dos veces el mismo sonido con nombres distintos.
  NO_SON_SONIDOS = %w[submitEnd].freeze
end
