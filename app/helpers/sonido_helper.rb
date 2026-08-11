# Los atributos que el `audio` de Stimulus necesita para saber qué tocar.
#
# Vive en un helper y no escrito en cada vista porque son **dos pantallas**
# —/etiquetar y /entrega_personal— y en este repo lo que se escribe dos veces
# se desincroniza: cuando `RP-20` agregó la variante, la copia de una de las
# dos se hubiera quedado sin ella y el error habría sonado distinto en cada
# pantalla. Con el helper, el próximo atributo llega a las dos solo.
module SonidoHelper
  def atributos_de_audio(usuario = Current.user)
    {
      "data-audio-enabled-value" => usuario&.sonido_habilitado != false,
      "data-audio-volumen-value" => usuario&.sonido_volumen || 60,
      "data-audio-variante-value" => usuario&.sonido_error_variante || SonidosDeError::DEFAULT,
      # Las tres opciones enteras, no solo la elegida: el modal de sonidos deja
      # probarlas sin recargar. Sale de la misma constante con la que se
      # rendearon los .wav que se le mandaron a Yusef.
      "data-audio-variantes-value" => SonidosDeError::VARIANTES.to_json
    }
  end

  def variante_de_error_actual(usuario = Current.user)
    usuario&.sonido_error_variante.presence || SonidosDeError::DEFAULT
  end
end
