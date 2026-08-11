require "test_helper"

# PR: las tres opciones del sonido de error (`RP-20`).
#
# Elegir un sonido es subjetivo y no hay test que diga si suena lindo. Lo que sí
# se puede fijar es que las tres sean **distinguibles de lo que ya suena**: un
# sonido de error que se parece al de "todo bien" no avisa nada, y el operario
# de bodega lo distingue de oído, sin mirar la pantalla.
class SonidosDeErrorTest < ActiveSupport::TestCase
  test "son tres, con ids unicos" do
    assert_equal 3, SonidosDeError::VARIANTES.size
    assert_equal SonidosDeError::IDS.uniq, SonidosDeError::IDS
  end

  test "la primera es la de hoy, y es el default" do
    # Que "no le muevan nada" sea una respuesta posible no es cortesía: si la
    # opción de dejarlo igual no está, la pregunta está mal hecha. Y así
    # cambiar el default es deliberado.
    assert_equal "grave", SonidosDeError::VARIANTES.first[:id]
    assert_equal "grave", SonidosDeError::DEFAULT
    assert_equal [ { hz: 200, ms: 300 } ], SonidosDeError::VARIANTES.first[:tonos]
  end

  test "ninguna sube de tono" do
    # `success` (800), `notify` (880→1320) y `alert` (600→900) suben. Un error
    # que sube se confunde con un aviso de que todo salió bien.
    suben = SonidosDeError::VARIANTES.select do |v|
      hz = SonidosDeError.frecuencias(v)
      hz.each_cons(2).any? { |a, b| b > a }
    end

    assert_empty suben.map { |v| v[:id] }
  end

  test "ninguna suena igual a un sonido que ya existe" do
    repetidas = SonidosDeError::VARIANTES.filter_map do |v|
      hz = SonidosDeError.frecuencias(v)
      choque = SonidosDeError::YA_TOMADOS.find { |_nombre, otras| otras == hz }
      "#{v[:id]} == #{choque.first}" if choque
    end

    assert_empty repetidas
  end

  test "todas dicen como suenan, en castellano" do
    # El texto va en el modal, al lado del radio: sin él las tres opciones son
    # tres palabras sueltas y no se pueden comparar sin escucharlas una por una.
    mudas = SonidosDeError::VARIANTES.reject { |v| v[:nombre].present? && v[:descripcion].present? }

    assert_empty mudas.map { |v| v[:id] }
  end

  test "todo tono tiene frecuencia y duracion sanas" do
    raros = SonidosDeError::VARIANTES.flat_map do |v|
      v[:tonos].filter_map do |t|
        next if t[:hz].between?(0, 4_000) && t[:ms].between?(20, 1_000)
        "#{v[:id]}: #{t.inspect}"
      end
    end

    assert_empty raros, "hz fuera de lo audible o duración absurda:\n#{raros.join("\n")}"
  end

  test "ninguna dura mas de medio segundo" do
    # Suena en cada escaneo malo. Un sonido largo se vuelve un estorbo y lo
    # primero que hace el operario es apagar todos los sonidos.
    largas = SonidosDeError::VARIANTES.select { |v| SonidosDeError.duracion_ms(v) > 500 }

    assert_empty largas.map { |v| v[:id] }
  end

  test "find cae en la primera si le dan una que no existe" do
    assert_equal "descendente", SonidosDeError.find("descendente")[:id]
    assert_equal "grave", SonidosDeError.find("la-que-sea")[:id]
    assert_equal "grave", SonidosDeError.find(nil)[:id]
  end

  test "los silencios no cuentan como tono" do
    triple = SonidosDeError.find("triple")

    assert_equal [ 320, 320, 320 ], SonidosDeError.frecuencias(triple)
    assert_equal 400, SonidosDeError.duracion_ms(triple)
  end
end
