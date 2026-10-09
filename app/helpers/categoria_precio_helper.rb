# Lo que queda del helper de categorías.
#
# `tarifa_precio` y `tarifa_tramo` se fueron con `PR-C7.12`: existían para el
# listado de categorías, que mostraba en solo lectura lo que cada una cobraba.
# Esa pantalla se fue y la información vive en /servicios, que ya tenía su propio
# formato de precio y de escalón. Dos formas de escribir el mismo número, y una
# sin usar, es exactamente la duplicación que este proyecto viene pagando.
module CategoriaPrecioHelper
  # El texto de confirmación antes de borrar.
  #
  # Las categorías que declara la hoja de precios de Yusef vuelven a aparecer en
  # la próxima siembra. Borrarlas es válido, pero no es permanente, y el usuario
  # tiene que saberlo **antes** de darle — no descubrirlo cuando reaparezcan.
  def borrar_categoria_confirmacion(categoria)
    base = "¿Eliminar el grupo \"#{categoria.nombre}\"?"

    if categoria.declarada_en_la_hoja?
      "#{base} Ojo: está en la hoja de precios, así que va a volver a crearse la próxima vez que se siembren las tarifas."
    else
      "#{base} No lo usa ningún cliente ni ninguna tarifa."
    end
  end
end
