require "test_helper"

# PR: los `.wav` que se le mandan a Yusef por WhatsApp (`RP-20`).
#
# Un WAV mal armado no revienta: el reproductor lo abre mudo, o lo abre cortado,
# o no lo abre y no dice por qué. Como el archivo se manda por WhatsApp y del
# otro lado no hay quien lo diagnostique, la cabecera se verifica acá byte por
# byte.
class SonidosWavTest < ActiveSupport::TestCase
  CABECERA = 44

  test "el archivo es un WAV que se puede abrir" do
    datos = SonidosWav.render(SonidosDeError.find("grave"))

    assert_equal "RIFF", datos[0, 4]
    assert_equal "WAVE", datos[8, 4]
    assert_equal "fmt ", datos[12, 4]
    assert_equal "data", datos[36, 4]
  end

  test "la cabecera no miente sobre el tamano" do
    # Es el error clásico de escribir un WAV a mano: declarar un largo y
    # escribir otro. Algunos reproductores lo toleran y otros no, así que el
    # bug aparece en el teléfono de Yusef y en ningún lado más.
    SonidosDeError::VARIANTES.each do |variante|
      datos = SonidosWav.render(variante)
      declarado = datos[40, 4].unpack1("V")
      riff = datos[4, 4].unpack1("V")

      assert_equal datos.bytesize - CABECERA, declarado, "#{variante[:id]}: el bloque `data` miente"
      assert_equal datos.bytesize - 8, riff, "#{variante[:id]}: el bloque `RIFF` miente"
    end
  end

  test "el formato es el que dice la cabecera" do
    datos = SonidosWav.render(SonidosDeError.find("grave"))
    _tam, formato, canales, rate, _byte_rate, _align, bits = datos[16, 20].unpack("VvvVVvv")

    assert_equal 1, formato, "1 es PCM sin comprimir; otra cosa necesita más cabecera"
    assert_equal SonidosWav::CANALES, canales
    assert_equal SonidosWav::SAMPLE_RATE, rate
    assert_equal SonidosWav::BITS, bits
  end

  test "dura lo que la variante dice que dura" do
    SonidosDeError::VARIANTES.each do |variante|
      datos = SonidosWav.render(variante)
      muestras = (datos.bytesize - CABECERA) / (SonidosWav::BITS / 8)
      ms = (muestras * 1000.0 / SonidosWav::SAMPLE_RATE).round

      assert_equal SonidosDeError.duracion_ms(variante), ms, "#{variante[:id]}"
    end
  end

  test "suena: no es un archivo de silencio" do
    # Con un signo mal puesto o una envolvente a cero el archivo sale del
    # tamaño correcto y completamente mudo. Pasaría todos los tests de arriba.
    datos = SonidosWav.render(SonidosDeError.find("grave"))
    muestras = datos[CABECERA..].unpack("s<*")

    assert_operator muestras.map(&:abs).max, :>, 10_000, "el archivo salió mudo o casi"
  end

  test "el silencio del triple es silencio de verdad" do
    triple = SonidosDeError.find("triple")
    datos = SonidosWav.render(triple)
    muestras = datos[CABECERA..].unpack("s<*")

    # El primer pulso son 80 ms; los 60 ms siguientes tienen que estar en cero.
    inicio_pausa = (SonidosWav::SAMPLE_RATE * 80 / 1000.0).round
    largo_pausa  = (SonidosWav::SAMPLE_RATE * 60 / 1000.0).round
    pausa = muestras[inicio_pausa, largo_pausa]

    assert_equal [ 0 ], pausa.uniq
  end

  test "cada variante tiene su propio nombre de archivo" do
    nombres = SonidosDeError::VARIANTES.map { |v| SonidosWav.nombre_de(v) }

    assert_equal nombres.uniq, nombres
    assert(nombres.all? { |n| n.end_with?(".wav") })
  end

  test "los tres archivos versionados estan al dia" do
    # Se commitean como los PDF de entregables. Si alguien cambia una variante y
    # no corre `docs:sonidos_wav`, el archivo que se manda por WhatsApp deja de
    # ser el que suena en la pantalla.
    dir = Rails.root.join("docs/entregables/sonidos")

    viejos = SonidosDeError::VARIANTES.filter_map do |variante|
      archivo = dir.join(SonidosWav.nombre_de(variante))
      next "#{archivo.basename} no existe" unless archivo.exist?
      archivo.basename.to_s unless archivo.binread == SonidosWav.render(variante)
    end

    assert_empty viejos, "corré `bin/rails docs:sonidos_wav`:\n#{viejos.join("\n")}"
  end
end
