require "test_helper"

# PR: que la pantalla y el archivo `.wav` toquen **lo mismo**.
#
# Las variantes las consumen dos cosas: el navegador, con osciladores, y
# `SonidosWav`, que las renderea para mandárselas a Yusef. Si el JS declarara su
# propia lista, en cuanto alguien tocara una de las dos el sonido del WhatsApp
# dejaría de ser el sonido de la bodega — y nadie se enteraría hasta que él
# dijera "ese no es el que escuché".
#
# Por eso la lista sale de Ruby y viaja en un data attribute. Este test fija ese
# camino.
class SonidoHelperTest < ActionView::TestCase
  include SonidoHelper

  # `Current.user` está delegado a `Current.session`, así que no se asigna
  # directo: se pone la sesión.
  setup do
    @user = users(:digitador)
    Current.session = Session.new(user: @user)
  end

  teardown { Current.session = nil }

  test "la vista manda las mismas variantes que definimos en Ruby" do
    json = atributos_de_audio["data-audio-variantes-value"]
    ida_y_vuelta = JSON.parse(json, symbolize_names: true)

    assert_equal SonidosDeError::VARIANTES, ida_y_vuelta
  end

  # PR-C29.9 · La voz del error viaja igual que las variantes: si el navegador
  # tuviera sus propios números, los .wav que se le mandan a Yusef y lo que
  # suena en la bodega serían dos sonidos distintos.
  test "la vista manda la misma voz de error que definimos en Ruby" do
    ida_y_vuelta = JSON.parse(atributos_de_audio["data-audio-voz-value"], symbolize_names: true)

    assert_equal SonidosDeError::VOZ, ida_y_vuelta
  end

  test "manda la variante del usuario, no la default" do
    @user.update!(sonido_error_variante: "triple")

    assert_equal "triple", atributos_de_audio["data-audio-variante-value"]
    assert_equal "triple", variante_de_error_actual
  end

  test "sin usuario cae en los valores de siempre" do
    # El partial se renderiza en pantallas donde `Current.user` puede no estar
    # puesto todavía; que reviente ahí dejaría la pantalla entera en blanco.
    Current.session = nil
    attrs = atributos_de_audio(nil)

    assert_equal true, attrs["data-audio-enabled-value"]
    assert_equal 60, attrs["data-audio-volumen-value"]
    assert_equal SonidosDeError::DEFAULT, attrs["data-audio-variante-value"]
  end

  test "estan los atributos que el controller de Stimulus lee" do
    # Si mañana se agrega uno, entra por acá y llega a las dos pantallas
    # solo. Escritos en cada vista, llegaba a una. C29-08 sumó tres: con qué
    # suena cada error con sonido propio, y cuántas veces.
    esperados = %w[
      data-audio-enabled-value data-audio-volumen-value
      data-audio-variante-value data-audio-variantes-value
      data-audio-por-motivo-value data-audio-repeticiones-value data-audio-pausa-value
      data-audio-voz-value
    ]

    assert_equal esperados.sort, atributos_de_audio.keys.sort
  end

  test "las dos pantallas usan el helper y no los atributos a mano" do
    vistas = %w[etiquetar/index entrega_personal/new].map do |v|
      [ v, Rails.root.join("app/views/#{v}.html.erb").read ]
    end

    a_mano = vistas.filter_map { |nombre, src| nombre if src.include?("data-audio-enabled-value=") }
    sin_helper = vistas.filter_map { |nombre, src| nombre unless src.include?("atributos_de_audio") }

    assert_empty a_mano, "escribe los atributos a mano en vez de usar el helper"
    assert_empty sin_helper
  end
end
