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

  # El texto de confirmación antes de borrar.
  #
  # Las categorías que declara la hoja de precios de Yusef vuelven a aparecer en
  # la próxima siembra. Borrarlas es válido, pero no es permanente, y el usuario
  # tiene que saberlo **antes** de darle — no descubrirlo cuando reaparezcan.
  def borrar_categoria_confirmacion(categoria)
    base = "¿Eliminar la categoría \"#{categoria.nombre}\"?"

    if categoria.declarada_en_la_hoja?
      "#{base} Ojo: está en la hoja de precios, así que va a volver a crearse la próxima vez que se siembren las tarifas."
    else
      "#{base} No la usa ningún cliente ni ninguna tarifa."
    end
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
