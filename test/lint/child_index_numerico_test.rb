require "test_helper"

# Un `child_index:` de texto hace que Rails **descarte la fila en silencio**.
#
# `permit` solo reconoce una colección anidada cuando la llave del índice
# matchea `/\A-?\d+\z/` — es `ActionController::Parameters.nested_attribute?`.
# Con una llave que no sea de dígitos, `permit` no la ve como colección, la
# filtra entera, y el modelo recibe `{}`.
#
# Lo que hace que sea peor que un error: **no falla nada**. El formulario se
# manda, el `update` devuelve `true` porque no hubo nada que asignar, sale el
# flash de éxito, y el dato no está. Así vivió la pantalla de guías: se escribía
# el número, decía «guardado.», y la lista seguía diciendo «Falta». Jorge:
# *"siempre sale que faltan guías de proveedor aunque se ponga algo"*.
#
# Los tests de controller no lo agarran porque arman los params a mano y nadie
# escribe un índice de texto a mano; el índice roto solo existe en el HTML.
#
# La excepción es `NEW_INDEX`, el centinela del `<template>`: el JS lo reemplaza
# por un número **antes** de que la fila exista en el DOM, así que nunca viaja.
class ChildIndexNumericoTest < ActiveSupport::TestCase
  FUENTES = (Rails.root.glob("app/views/**/*.erb") + Rails.root.glob("app/components/**/*.erb")).freeze

  # `child_index: "algo"` o `child_index: algo`, hasta la coma o el cierre.
  CHILD_INDEX = /child_index:\s*("[^"]*"|'[^']*'|[\w.\[\]]+)/

  # El único texto permitido, y solo porque el JS lo pisa antes de que exista.
  CENTINELA = "NEW_INDEX"

  def usos
    FUENTES.flat_map do |archivo|
      contenido = archivo.read
      contenido.scan(CHILD_INDEX).map do |captura|
        { archivo: archivo.relative_path_from(Rails.root).to_s, valor: captura.first, contenido: contenido }
      end
    end
  end

  test "ningún child_index es una cadena que no sea el centinela" do
    malos = usos.select { |u| literal_de_texto?(u[:valor]) && desnudo(u[:valor]) != CENTINELA }

    assert_empty malos.map { |u| "#{u[:archivo]}: child_index: #{u[:valor]}" }, <<~MSG
      Estos `child_index` son cadenas de texto, y Rails va a **tirar la fila en
      silencio**: `permit` solo arma la colección anidada si el índice es de
      dígitos. Poné un número (`child_index: 0`) o, si es la fila del
      `<template>` que el JS clona, `"#{CENTINELA}"`.
    MSG
  end

  test "el centinela solo vive adentro de un template" do
    # Fuera de un `<template>` nadie lo reemplaza, así que viaja tal cual y la
    # fila se pierde igual que con cualquier otro texto.
    sueltos = usos.select { |u| desnudo(u[:valor]) == CENTINELA && !u[:contenido].include?("<template") }

    assert_empty sueltos.map { |u| u[:archivo] },
                 "`#{CENTINELA}` fuera de un `<template>`: nadie lo reemplaza y la fila se pierde."
  end

  test "el regex de verdad engancha los child_index que hay" do
    # La trampa de este repo: un lint cuyo patrón dejó de coincidir pasa en
    # verde para siempre. Si `fields_for` cambia de forma, esto avisa.
    assert_operator usos.size, :>=, 5,
                    "el regex dejó de enganchar: había 7 `child_index` en el repo"
    assert_includes usos.map { |u| u[:archivo] }, "app/views/guias_aduana/edit.html.erb",
                    "la pantalla donde se descubrió el bug tiene que seguir cubierta"

    # Y que sepa distinguir: un texto cualquiera es malo, un número no.
    assert literal_de_texto?('"nueva"'), "no reconoce una cadena"
    refute literal_de_texto?("0"), "confunde un número con una cadena"
    refute literal_de_texto?("index"), "confunde una variable con una cadena"
  end

  private

  def literal_de_texto?(valor)
    valor.start_with?('"', "'")
  end

  def desnudo(valor)
    valor.delete('"').delete("'")
  end
end
