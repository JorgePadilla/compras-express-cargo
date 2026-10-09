# Renderea una variante de `SonidosDeError` a un archivo `.wav`, para poder
# mandársela a Yusef por WhatsApp.
#
# En Ruby puro y a mano: un WAV PCM son 44 bytes de cabecera y las muestras
# crudas. Meter una gema —o depender de `ffmpeg`, que está en esta máquina pero
# no en Render— para escribir 44 bytes sería peor.
#
# Suena igual que en la pantalla porque **sale de las mismas constantes** y
# hace la misma cuenta que el navegador: la `VOZ` de `SonidosDeError` —dos
# ondas a un semitono, sostenidas, saturadas con la misma curva `tanh`—.
#
# PR-C29.9 · Hasta el 2026-10-08 era una cuadrada sola con caída exponencial
# desde la primera muestra, y así sonaba: un «tic» que se apagaba. Jorge: *"el
# audio de error tiene que ser más cruel, fuerte, molesto, intenso"*. La onda
# cuadrada se queda —a volumen bajo el `sine` se pierde entre el ruido de
# bodega, lo dijo Yusef desde Tegus—, y ahora tiene compañía.
module SonidosWav
  SAMPLE_RATE = 44_100
  BITS = 16
  CANALES = 1

  # El archivo se renderea con el volumen al máximo, que es como conviene
  # juzgarlo en el parlante de un celular. Antes topaba en 0.9 porque «más
  # arriba el oscilador satura y suena sucio»; ahora sucio es lo que se busca,
  # y la curva de saturación ya no deja pasar del techo.
  GANANCIA = 1.0

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

    voz = SonidosDeError::VOZ
    segunda = hz * voz[:segunda]

    total.times.map do |i|
      t = i / SAMPLE_RATE.to_f
      # La cuadrada en la nota: la primera mitad de cada ciclo arriba, la otra
      # abajo. La sierra, un semitono arriba: sube de -1 a 1 en cada ciclo.
      cuadrada = ((t * hz) % 1.0) < 0.5 ? 1.0 : -1.0
      sierra = 2.0 * ((t * segunda) % 1.0) - 1.0
      mezcla = voz[:mezcla] * (cuadrada + sierra)

      valor = GANANCIA * SonidosDeError.saturar(envolvente(i, total) * mezcla)
      (valor * 32_767).round.clamp(-32_768, 32_767)
    end
  end

  # Sostenida: sube en `ataque_ms`, se queda arriba, y cae en los últimos
  # `caida_ms`. Las rampas son lineales, como las `linearRampToValueAtTime`
  # del navegador.
  def self.envolvente(i, total)
    voz = SonidosDeError::VOZ
    ataque = SAMPLE_RATE * voz[:ataque_ms] / 1000.0
    caida = SAMPLE_RATE * voz[:caida_ms] / 1000.0

    [ i / ataque, (total - i) / caida, 1.0 ].min
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

  private_class_method :muestras_de, :envolvente, :cabecera
end
