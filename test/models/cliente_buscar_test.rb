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
end
