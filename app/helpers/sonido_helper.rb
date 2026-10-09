# Los atributos que el `audio` de Stimulus necesita para saber qué tocar.
#
# Vive en un helper y no escrito en cada vista porque son **cuatro pantallas**
# —/etiquetar, /entrega_personal, /empacar y /recepcion_carga— y acá lo que se escribe
# dos veces se desincroniza: cuando `RP-20` agregó la variante, la copia de una
# se hubiera quedado sin ella y el error habría sonado distinto en cada
# pantalla. Con el helper, el próximo atributo llega a todas solo.
#
# C25-10 · Y aun con el helper, `/empacar` **no lo llamaba** (ni `/recepcion_carga`,
# que el lint encontró al escribirse): montaba `audio`
# sin atributos, así que `error()` caía siempre al tono de respaldo y el
# volumen del usuario no aplicaba. Es lo que Yusef oyó como *"muy suavecito"*.
# Un helper compartido no sirve si a una pantalla se le olvida llamarlo.
module SonidoHelper
  def atributos_de_audio(usuario = Current.user)
    {
      "data-audio-enabled-value" => usuario&.sonido_habilitado != false,
      "data-audio-volumen-value" => usuario&.sonido_volumen || 60,
      "data-audio-variante-value" => usuario&.sonido_error_variante || SonidosDeError::DEFAULT,
      # Las tres opciones enteras, no solo la elegida: el modal de sonidos deja
      # probarlas sin recargar. Sale de la misma constante con la que se
      # rendearon los .wav que se le mandaron a Yusef.
      "data-audio-variantes-value" => SonidosDeError::VARIANTES.to_json,
      # C29-08 · Con qué variante suena cada error con sonido propio, y cuántas
      # veces.
      "data-audio-por-motivo-value" => SonidosDeError::MOTIVOS.to_h { |m| [ m[:id], variante_de_motivo(m[:id], usuario) ] }.to_json,
      "data-audio-repeticiones-value" => SonidosDeError::REPETICIONES,
      "data-audio-pausa-value" => SonidosDeError::PAUSA_MS
    }
  end

  def variante_de_motivo(id, usuario = Current.user)
    motivo = SonidosDeError.motivo(id)
    usuario&.public_send(motivo[:columna]).presence || motivo[:default]
  end

  def variante_de_error_actual(usuario = Current.user)
    usuario&.sonido_error_variante.presence || SonidosDeError::DEFAULT
  end
end
