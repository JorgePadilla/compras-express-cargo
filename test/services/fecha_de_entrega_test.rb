require "test_helper"

# C31-11 · La regla de los días hábiles, con los ejemplos que Yusef contó en voz
# alta (16:07 min 12–18). Octubre de 2026: el viernes es el 16.
class FechaDeEntregaTest < ActiveSupport::TestCase
  VIERNES = Date.new(2026, 10, 16)

  def calcular(dias, desde: VIERNES)
    FechaDeEntrega.calcular(desde: desde, dias: dias)
  end

  # *"Llega viernes, 1 2 3 4 5 6 7 8 9 10"*.
  test "recibido un viernes, 10 días hábiles caen el viernes de dos semanas después" do
    assert_equal Date.new(2026, 10, 30), calcular(10)
  end

  # *"Pero como el último día es sábado, sí lo cuenta."*
  test "con 11 días el último cae sábado, y el sábado cuenta" do
    assert_equal Date.new(2026, 10, 31), calcular(11)
    assert calcular(11).saturday?
  end

  # *"El 12 ya no lo cuenta porque cae… martes."* Ni sábado ni lunes.
  test "con 12 días el sábado ya no es el último: no cuenta, y cae martes" do
    assert_equal Date.new(2026, 11, 3), calcular(12)
    assert calcular(12).tuesday?
  end

  # *"Llegó el viernes… ya no contás el sábado, contás el lunes."*
  test "se empieza a contar el día siguiente, y el sábado del medio no cuenta" do
    assert_equal Date.new(2026, 10, 16), calcular(1, desde: Date.new(2026, 10, 15))
    assert_equal Date.new(2026, 10, 20), calcular(2)
  end

  # *"No puede iniciar el sábado."* Con un solo día, el sábado sería el primero
  # y el último a la vez: no se empieza en sábado (RP-101).
  test "el sábado no puede ser el primer día" do
    assert_equal Date.new(2026, 10, 19), calcular(1)
  end

  test "el domingo no cuenta nunca, ni siendo el último" do
    resultados = (1..30).map { |dias| calcular(dias) }
    assert resultados.none?(&:sunday?)
  end

  test "recibido en fin de semana se empieza el lunes" do
    sabado = Date.new(2026, 10, 17)
    domingo = Date.new(2026, 10, 18)
    assert_equal Date.new(2026, 10, 19), calcular(1, desde: sabado)
    assert_equal Date.new(2026, 10, 19), calcular(1, desde: domingo)
  end

  test "un feriado entre semana corre la fecha un día" do
    sin_feriado = calcular(7)
    Feriado.create!(fecha: Date.new(2026, 10, 21), nombre: "Prueba")
    assert_equal sin_feriado.next_day, calcular(7)
  end

  # RP-101: un feriado que cae en sábado bloquea ese sábado.
  test "un feriado en el sábado que iba a ser el último lo corre al lunes" do
    Feriado.create!(fecha: Date.new(2026, 10, 31), nombre: "Prueba")
    assert_equal Date.new(2026, 11, 2), calcular(11)
  end

  test "la recepción se lee en la hora de Honduras, no en UTC" do
    # Jueves 15 a las 7 de la noche en Honduras ya es viernes 16 en UTC.
    jueves_noche = Time.zone.local(2026, 10, 15, 19, 0)
    assert_equal Date.new(2026, 10, 16), calcular(1, desde: jueves_noche.utc)
  end

  test "sin días o sin fecha no hay fecha" do
    assert_nil calcular(nil)
    assert_nil calcular(0)
    assert_nil FechaDeEntrega.calcular(desde: nil, dias: 7)
  end

  test "el texto es el día y la fecha" do
    assert_equal "sábado 31/10", FechaDeEntrega.texto(Date.new(2026, 10, 31))
  end
end
