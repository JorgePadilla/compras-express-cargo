require "test_helper"

# El reparto de íconos es una decisión, así que se afirma.
#
# Jorge, mirando el selector: *"veo varios iconos repetidos para tipos de
# envío… hay muchos iconos, me parece que podemos variar"*. Antes el ícono
# salía **solo de la modalidad**: tres aviones iguales y dos camiones iguales,
# y encima `cka`/`ckm` compartían el gris del `else`.
class TipoEnvioPresentationHelperTest < ActionView::TestCase
  include TipoEnvioPresentationHelper

  SERVICIOS = %w[express cer cka cem ckm].freeze

  def tipo(codigo, modalidad: "aereo")
    TipoEnvio.new(codigo: codigo, modalidad: modalidad)
  end

  test "cada servicio tiene su propio icono" do
    iconos = SERVICIOS.map { |c| tipo_envio_icono(tipo(c)) }

    assert_equal iconos.uniq.size, iconos.size,
                 "se repite un ícono entre los cinco: #{iconos.inspect}"
  end

  test "maritimo lleva barco, y ya no camion" do
    assert_equal :barco, tipo_envio_icono(tipo("cem"))

    SERVICIOS.each do |codigo|
      refute_equal "truck", tipo_envio_icono(tipo(codigo)),
                   "#{codigo} sigue con el camión, que era el ícono equivocado"
    end
  end

  # Lo que sostiene que el ícono pueda ser distinto en cada uno: la modalidad
  # la dice el color.
  test "el color agrupa por modalidad" do
    assert_equal tipo_envio_accent(tipo("cer"))[:text],
                 tipo_envio_accent(tipo("cka"))[:text], "los dos aéreos comparten color"

    assert_equal tipo_envio_accent(tipo("cem"))[:text],
                 tipo_envio_accent(tipo("ckm"))[:text], "los dos marítimos comparten color"

    refute_equal tipo_envio_accent(tipo("cer"))[:text],
                 tipo_envio_accent(tipo("cem"))[:text], "aéreo y marítimo se distinguen"
  end

  # `cka`/`ckm` caían al gris del `else` y quedaban idénticas entre sí.
  test "ningun servicio se cae al gris de descarte" do
    SERVICIOS.each do |codigo|
      refute_equal "text-slate-600", tipo_envio_accent(tipo(codigo))[:text],
                   "#{codigo} no tiene color propio y cae al `else`"
    end
  end

  # Un `codigo` que no está en la tabla —los `*-legacy`, o un servicio nuevo
  # creado desde /servicios— tiene que salir con algo razonable igual.
  test "un servicio desconocido se cae a la modalidad" do
    assert_equal :barco, tipo_envio_icono(tipo("cem-legacy", modalidad: "maritimo"))
    assert_equal "paper-airplane", tipo_envio_icono(tipo("lo-que-sea", modalidad: "aereo"))
  end
end
