# Renderea una variante de `SonidosDeError` a un archivo `.wav`, para poder
# mandársela a Yusef por WhatsApp.
#
# En Ruby puro y a mano: un WAV PCM son 44 bytes de cabecera y las muestras
# crudas. Meter una gema —o depender de `ffmpeg`, que está en esta máquina pero
# no en Render— para escribir 44 bytes sería peor.
#
# Suena igual que en la pantalla porque **sale de la misma constante** y copia
# lo que hace el navegador: onda cuadrada y caída exponencial de la ganancia.
# `square` y no `sine` porque a volumen bajo el `sine` se pierde entre el ruido
# de bodega — eso lo dijo Yusef desde Tegus y por eso está así en el
# `audio_controller`.
module SonidosWav
  SAMPLE_RATE = 44_100
  BITS = 16
  CANALES = 1

  # El navegador topa la ganancia en 0.9 (más arriba el oscilador satura y suena
  # sucio). El archivo se renderea a ese tope: es el sonido "al máximo", que es
  # como conviene juzgarlo en el parlante de un celular.
  GANANCIA = 0.9

  # A dónde cae la ganancia al final de cada tono. Es el mismo 0.001 del
  # `exponentialRampToValueAtTime` del navegador — no puede ser 0 porque una
  # rampa exponencial a cero no existe.
  PISO = 0.001

  def self.render(variante)
    muestras = variante[:tonos].flat_map { |t| muestras_de(t[:hz], t[:ms]) }
    cabecera(muestras.size * 2) + muestras.pack("s<*")
  end

  def self.render_file(variante, ruta)
    File.binwrite(ruta, render(variante))
  end

  # Cómo se llama el archivo de cada variante.
  def self.nombre_de(variante) = "error_#{variante[:id]}.wav"

  def self.muestras_de(hz, ms)
    total = (SAMPLE_RATE * ms / 1000.0).round
    return Array.new(total, 0) if hz.to_i.zero?

    total.times.map do |i|
      t = i / SAMPLE_RATE.to_f
      # Onda cuadrada: la primera mitad de cada ciclo arriba, la otra abajo.
      signo = ((t * hz) % 1.0) < 0.5 ? 1 : -1
      envolvente = GANANCIA * ((PISO / GANANCIA)**(i / total.to_f))
      (signo * envolvente * 32_767).round.clamp(-32_768, 32_767)
    end
  end

  # RIFF/WAVE, 44 bytes. El largo se calcula de los datos que se van a escribir
  # y nunca se escribe a mano: una cabecera que miente sobre el tamaño da un
  # archivo que algunos reproductores abren mudo y otros no abren.
  def self.cabecera(bytes_de_datos)
    byte_rate = SAMPLE_RATE * CANALES * BITS / 8
    block_align = CANALES * BITS / 8

    "RIFF".b +
      [ 36 + bytes_de_datos ].pack("V") +
      "WAVE".b + "fmt ".b +
      [ 16, 1, CANALES, SAMPLE_RATE, byte_rate, block_align, BITS ].pack("VvvVVvv") +
      "data".b + [ bytes_de_datos ].pack("V")
  end

  private_class_method :muestras_de, :cabecera
end
