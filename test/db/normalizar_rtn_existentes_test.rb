require "test_helper"
require Rails.root.join("db/migrate/20261010170000_normalizar_rtn_existentes").to_s

# PR-F1.7 · Los RTN viejos, sin guiones ni espacios, para que la búsqueda por
# RTN encuentre a los clientes de antes de la facturación SAR. Se corre la
# migración de verdad (su `up`) sobre filas sucias escritas con SQL, como
# quedaron cuando el RTN era texto libre.
class NormalizarRtnExistentesTest < ActiveSupport::TestCase
  # Con SQL: `ConRtn` normalizaría al asignar, y lo que se prueba es lo que ya
  # estaba guardado tal cual.
  def ensuciar(registro, rtn)
    tabla = registro.class.table_name
    registro.class.connection.execute(
      "UPDATE #{tabla} SET rtn = #{registro.class.connection.quote(rtn)} WHERE id = #{registro.id.to_i}"
    )
  end

  def guardado(registro)
    registro.class.connection.select_value("SELECT rtn FROM #{registro.class.table_name} WHERE id = #{registro.id.to_i}")
  end

  def migrar
    salida = StringIO.new
    migracion = NormalizarRtnExistentes.new
    migracion.verbose = true
    $stdout, antes = salida, $stdout
    migracion.up
    salida.string
  ensure
    $stdout = antes
  end

  setup do
    # Las fixtures traen tres clientes; para los casos hacen falta más.
    @clientes = Cliente.order(:id).to_a +
                (1..4).map { |i| Cliente.create!(nombre: "RTN viejo #{i}") }
    @empresa = Empresa.first
  end

  test "saca guiones y espacios cuando quedan 14 dígitos, en clientes y en la empresa" do
    con_guiones, con_espacios, con_tab = @clientes
    ensuciar(con_guiones, "0801-1998-123456")
    ensuciar(con_espacios, " 0801 1998 222222 ")
    ensuciar(con_tab, "0801\t1998-33333\n3")
    ensuciar(@empresa, "0501-2000-000123")

    migrar

    assert_equal "08011998123456", guardado(con_guiones)
    assert_equal "08011998222222", guardado(con_espacios)
    assert_equal "08011998333333", guardado(con_tab)
    assert_equal "05012000000123", guardado(@empresa)
    assert_equal con_guiones.id, Cliente.find_by(rtn: "0801-1998-123456")&.id,
                 "la búsqueda por RTN (que normaliza la consulta) encuentra al cliente viejo"
  end

  test "nunca inventa dígitos: lo que no da 14 se queda como está, y lo cuenta" do
    letras, corto, largo, vacio, en_blanco, punto = @clientes
    ensuciar(letras, "RTN 0801-1998-123456")
    ensuciar(corto, "0801-1998-12345")
    ensuciar(largo, "0801-1998-1234567")
    ensuciar(vacio, "")
    ensuciar(en_blanco, "   ")
    ensuciar(punto, "0801.1998.123456")
    Empresa.connection.execute("UPDATE empresas SET rtn = NULL")

    salida = migrar

    assert_equal "RTN 0801-1998-123456", guardado(letras)
    assert_equal "0801-1998-12345", guardado(corto)
    assert_equal "0801-1998-1234567", guardado(largo)
    assert_equal "", guardado(vacio)
    assert_equal "   ", guardado(en_blanco)
    assert_equal "0801.1998.123456", guardado(punto), "el punto no es separador para ConRtn: tampoco acá"
    assert_nil guardado(@empresa)
    fuera = Cliente.connection.select_value(
      "SELECT COUNT(*) FROM clientes WHERE rtn IS NOT NULL AND rtn <> '' AND rtn !~ '^[0-9]{14}$'"
    ).to_i
    assert_match(/clientes: 0 RTN normalizados; #{fuera} siguen sin ser 14 dígitos/, salida)
    assert_operator fuera, :>=, 5
  end

  test "lo que ya está bien no se toca, y correrla dos veces no cambia nada" do
    bien, sucio = @clientes
    ensuciar(bien, "08011998123456")
    ensuciar(sucio, "0801-1998-654321")
    actualizado = Cliente.connection.select_value("SELECT updated_at FROM clientes WHERE id = #{bien.id}")

    migrar
    assert_equal "08011998654321", guardado(sucio)

    segunda = migrar
    assert_equal "08011998123456", guardado(bien)
    assert_equal "08011998654321", guardado(sucio)
    assert_equal actualizado, Cliente.connection.select_value("SELECT updated_at FROM clientes WHERE id = #{bien.id}")
    assert_match(/clientes: 0 RTN normalizados/, segunda)
  end

  test "lo que deja normalizado es lo mismo que ConRtn guardaría" do
    cliente = @clientes.first
    ensuciar(cliente, "0801 - 1998 - 123456")

    migrar

    assert_equal Fiscal.normalizar_rtn("0801 - 1998 - 123456"), guardado(cliente)
    assert Cliente.find(cliente.id).valid?, "el cliente queda guardable"
  end
end
