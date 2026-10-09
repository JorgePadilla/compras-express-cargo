require "test_helper"

# PR: las tres opciones del sonido de error (`RP-20`).
#
# Elegir un sonido es subjetivo y no hay test que diga si suena lindo. Lo que sí
# se puede fijar es que las tres sean **distinguibles de lo que ya suena**: un
# sonido de error que se parece al de "todo bien" no avisa nada, y el operario
# de bodega lo distingue de oído, sin mirar la pantalla.
class SonidosDeErrorTest < ActiveSupport::TestCase
  # Eran tres (`RP-20`); la cuarta la pidió Yusef el 2026-09-05 (`C25-10`); la
  # quinta, la «alarma», salió de Jorge el 2026-10-08 (`PR-C29.9`).
  test "son cinco, con ids unicos" do
    assert_equal 5, SonidosDeError::VARIANTES.size
    assert_equal SonidosDeError::IDS.uniq, SonidosDeError::IDS
  end

  # *"Tiene que ser más como pit que tú"*: de todas, una tiene que ser
  # claramente más alta que las demás, y plana — que el «agudo» no sea un
  # grave con otro nombre.
  test "hay una aguda, y es la única por encima de los 1000 Hz" do
    agudas = SonidosDeError::VARIANTES.select { |v| SonidosDeError.frecuencias(v).min >= 1_000 }

    assert_equal [ "agudo" ], agudas.map { |v| v[:id] }
    assert_equal 1, SonidosDeError.frecuencias(SonidosDeError.find("agudo")).uniq.size, "plana, no sube ni baja"
  end

  # PR-C29.9 · El default cambió, y a propósito. Jorge, 2026-10-08: *"el audio
  # de error creo que tiene que ser más cruel, fuerte, molesto, intenso"*. La
  # primera es el default —así cambiarlo sigue siendo mover una línea, no un
  # descuido— y el sonido de siempre se queda como opción.
  test "la primera es la alarma, y es el default; la de siempre sigue estando" do
    assert_equal "alarma", SonidosDeError::VARIANTES.first[:id]
    assert_equal "alarma", SonidosDeError::DEFAULT
    assert_equal [ { hz: 200, ms: 300 } ], SonidosDeError.find("grave")[:tonos]
  end

  test "la alarma son cinco zumbidos iguales y rápidos" do
    alarma = SonidosDeError.find("alarma")

    assert_equal [ 400 ] * 5, SonidosDeError.frecuencias(alarma)
    assert(alarma[:tonos].all? { |t| t[:ms] <= 60 }, "rápidos: ningún golpe ni pausa pasa de 60 ms")
  end

  test "la columna de users arranca en el mismo default" do
    assert_equal SonidosDeError::DEFAULT, User.columns_hash["sonido_error_variante"].default
  end

  # La voz que vuelve áspero cualquier error. Lo que se fija es lo que la hace
  # molesta: dos notas a un semitono (no una sola, no una consonancia), una
  # saturación que de verdad aplasta, y que nunca pase del techo.
  test "la voz del error son dos notas a un semitono, saturadas sin pasarse del techo" do
    voz = SonidosDeError::VOZ

    assert_in_delta 2**(1 / 12.0), voz[:segunda], 0.001
    assert_operator voz[:saturacion], :>=, 2, "con menos, la curva casi no aplasta y vuelve el «tic»"
    assert_in_delta 1.0, SonidosDeError.saturar(1.0), 1e-9
    assert_in_delta(-1.0, SonidosDeError.saturar(-5.0), 1e-9)
    assert_operator SonidosDeError.saturar(0.5), :>, 0.9, "a media onda ya tiene que estar casi en el techo"
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
    assert_equal "alarma", SonidosDeError.find("la-que-sea")[:id]
    assert_equal "alarma", SonidosDeError.find(nil)[:id]
  end

  test "los silencios no cuentan como tono" do
    triple = SonidosDeError.find("triple")

    assert_equal [ 320, 320, 320 ], SonidosDeError.frecuencias(triple)
    assert_equal 400, SonidosDeError.duracion_ms(triple)
  end

  # C29-08 · *"Si el tipo de envío es el error, tiene que tirar un sonido de una
  # forma. Si la sucursal es el error… de otro tono."*
  test "los errores con sonido propio arrancan en variantes que existen, distintas entre sí y del error de siempre" do
    defaults = SonidosDeError::MOTIVOS.map { |m| m[:default] }

    assert(defaults.all? { |d| SonidosDeError::IDS.include?(d) })
    assert_equal defaults.uniq, defaults, "dos errores con el mismo sonido no se distinguen"
    assert_not_includes defaults, SonidosDeError::DEFAULT, "tienen que sonar distinto del error de siempre"
  end

  test "cada error con sonido propio tiene su columna en users, con el mismo default" do
    SonidosDeError::MOTIVOS.each do |m|
      columna = User.columns_hash[m[:columna].to_s]
      assert columna, "falta users.#{m[:columna]}"
      assert_equal m[:default], columna.default
    end
  end
end
