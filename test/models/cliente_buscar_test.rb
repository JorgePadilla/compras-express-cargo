require "test_helper"

# PR-10.c: la búsqueda que usa el operario al etiquetar.
class ClienteBuscarTest < ActiveSupport::TestCase
  setup do
    @juan = clientes(:juan)   # fixture: CEC-001, Juan Perez
    @juan.update!(codigo: "C2", nombre: "Juan", apellido: "Perez")
  end

  test "encuentra por nombre y apellido juntos" do
    assert_includes Cliente.buscar("Juan Perez"), @juan,
                    "antes devolvia 0: ninguna columna sola contiene la cadena completa"
  end

  test "encuentra por nombre o apellido sueltos" do
    assert_includes Cliente.buscar("Juan"), @juan
    assert_includes Cliente.buscar("Perez"), @juan
  end

  test "encuentra por codigo exacto" do
    assert_includes Cliente.buscar("C2"), @juan
  end

  test "ignora los ceros a la izquierda del codigo" do
    assert_includes Cliente.buscar("C002"), @juan, "C002 debe encontrar a C2"
    assert_includes Cliente.buscar("002"), @juan
    assert_includes Cliente.buscar("2"), @juan
  end

  test "combina codigo y nombre en un solo termino" do
    # "a veces llegan las etiquetas rotas: solo dicen 234 y despues Perez"
    assert_includes Cliente.buscar("2 Juan"), @juan
    assert_includes Cliente.buscar("002 Perez"), @juan
  end

  test "no devuelve clientes que solo matchean una parte del termino" do
    otro = Cliente.create!(codigo: "C99", nombre: "Maria", apellido: "Lopez")

    resultados = Cliente.buscar("Juan Perez")

    assert_not_includes resultados, otro
  end

  test "es case insensitive" do
    assert_includes Cliente.buscar("juan perez"), @juan
    assert_includes Cliente.buscar("JUAN PEREZ"), @juan
  end

  test "un termino vacio no rompe" do
    assert_nothing_raised { Cliente.buscar("").to_a }
    assert_nothing_raised { Cliente.buscar("   ").to_a }
  end

  # ── PR-10.f: la etiqueta rota ──
  #
  # "A veces llegan las etiquetas rotas, solo dicen 234 y después dice Pérez
  #  Hernández, entonces uno tiene que andar ahí unificando." — Yusef

  test "encuentra al cliente aunque un fragmento de la etiqueta no exista" do
    @juan.update!(codigo: "C234", nombre: "Juan", apellido: "Perez")

    # El operario lee "234" y "Perez Hernandez" de una etiqueta rota, pero el
    # cliente no tiene "Hernandez".
    assert_empty Cliente.buscar("234 Perez Hernandez"),
                 "la estricta sigue fallando — es lo que motiva el fallback"
    assert_includes Cliente.buscar_flexible("234 Perez Hernandez"), @juan
  end

  test "el que matchea mas fragmentos queda primero" do
    @juan.update!(codigo: "C234", nombre: "Juan", apellido: "Perez")
    otro = Cliente.create!(codigo: "C99", nombre: "Ana", apellido: "Perez")

    resultados = Cliente.buscar_flexible("234 Perez Hernandez").to_a

    assert_equal @juan, resultados.first, "C234 Perez matchea 2 fragmentos, Ana Perez solo 1"
    assert_includes resultados, otro
  end

  # ── Acentos ──

  test "encuentra con acento cuando la base no lo tiene" do
    @juan.update!(nombre: "Juan", apellido: "Perez")

    assert_includes Cliente.buscar("Pérez"), @juan
  end

  test "encuentra sin acento cuando la base si lo tiene" do
    @juan.update!(nombre: "Juan", apellido: "Pérez")

    assert_includes Cliente.buscar("Perez"), @juan
  end

  test "los acentos tampoco estorban en la busqueda combinada" do
    @juan.update!(codigo: "C234", nombre: "Juan", apellido: "Pérez")

    assert_includes Cliente.buscar("234 Perez"), @juan
    assert_includes Cliente.buscar_flexible("234 Perez Hernandez"), @juan
  end

  # ── Sin regresiones ──

  test "cuando la estricta encuentra algo, la flexible devuelve lo mismo" do
    @juan.update!(codigo: "C2", nombre: "Juan", apellido: "Perez")

    assert_equal Cliente.buscar("Juan Perez").to_a,
                 Cliente.buscar_flexible("Juan Perez").to_a
  end

  test "con una sola palabra la flexible no afloja la busqueda" do
    @juan.update!(nombre: "Juan", apellido: "Perez")
    otro = Cliente.create!(codigo: "C99", nombre: "Ana", apellido: "Lopez")

    assert_not_includes Cliente.buscar_flexible("Perez"), otro
  end

  test "el filtro del listado sigue siendo estricto" do
    @juan.update!(codigo: "C234", nombre: "Juan", apellido: "Perez")

    # `buscar` es la que usa clientes#index — filtrar es filtrar.
    assert_empty Cliente.buscar("234 Perez Hernandez")
  end
end
