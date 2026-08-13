# Cómo se lee una tarifa cuando se la muestra fuera de /servicios.
#
# El punto de estos dos helpers es **la moneda**. La pantalla de categorías
# rotulaba todo en lempiras cuando los números eran dólares, y esa fue una de las
# dos cosas que Yusef reportó. Acá el símbolo sale del dato, no de una constante
# en la vista: si la tarifa dice USD se ve `$`, si dice LPS se ve `L.`
module CategoriaPrecioHelper
  SIMBOLOS = { "USD" => "$", "LPS" => "L." }.freeze

  def tarifa_precio(tarifa)
    simbolo = SIMBOLOS.fetch(tarifa.moneda.to_s, "#{tarifa.moneda} ")
    "#{simbolo}#{number_with_precision(tarifa.precio_libra, precision: 2)}/lb"
  end

  # El tramo de peso al que aplica. `hasta_libras` en nil significa "de ahí para
  # arriba", y decirlo así evita el "0 → " que confundía en /servicios.
  def tarifa_tramo(tarifa)
    desde = number_with_precision(tarifa.desde_libras, precision: 0)

    if tarifa.hasta_libras.blank?
      tarifa.desde_libras.to_f.zero? ? "" : "· desde #{desde} lb"
    else
      "· #{desde}–#{number_with_precision(tarifa.hasta_libras, precision: 0)} lb"
    end
  end
end
