require "test_helper"

# C33-05 · Las direcciones del casillero, como «Mis Direcciones» del sistema
# viejo: Miami una vez por servicio, con su «Línea 2».
class DireccionesDelCasilleroTest < ActiveSupport::TestCase
  setup do
    @juan = clientes(:juan)
  end

  test "un bloque de Miami por servicio activo con linea 2, con el nombre del cliente" do
    bloques = DireccionesDelCasillero.new(@juan).bloques
    cer = bloques.find { |b| b.titulo == "Miami · CER" }

    assert cer
    campos = cer.campos.to_h
    assert_equal "CEC-001 #{@juan.nombre_completo.upcase}", campos["Nombre"]
    assert_equal "8109 NW 60TH STREET", campos["Línea 1"]
    assert_equal "REEMPAQUE AEREO", campos["Línea 2"]
    assert_equal "33195-3415", campos["Código postal"]
    assert_match "Aéreo con reempaque", cer.descripcion
  end

  test "el servicio sin linea 2 o inactivo no sale" do
    tipo_envios(:cka).update!(linea_2_casillero: nil)
    tipo_envios(:ckm).update!(activo: false)

    titulos = DireccionesDelCasillero.new(@juan).bloques.map(&:titulo)

    assert_not_includes titulos, "Miami · CKA"
    assert_not_includes titulos, "Miami · CKM"
    assert_includes titulos, "Miami · CEM"
  end

  test "aereos primero, como en el sistema viejo" do
    titulos = DireccionesDelCasillero.new(@juan).bloques.map(&:titulo)

    assert_equal [ "Miami · CER", "Miami · CKA", "Miami · EXPRESS", "Miami · CEM", "Miami · CKM" ], titulos.first(5)
  end

  test "sin cliente, el nombre es la instruccion" do
    bloque = DireccionesDelCasillero.new.bloques.first

    assert_equal DireccionesDelCasillero::SIN_CLIENTE, bloque.campos.to_h["Nombre"]
  end

  test "el texto para copiar va una linea por campo" do
    texto = DireccionesDelCasillero.new(@juan).bloques.first.texto

    assert_match(/\ANombre: CEC-001 .+\nLínea 1: 8109 NW 60TH STREET\nLínea 2: /, texto)
  end

  test "otra bodega de recepcion sale solo si tiene direccion cargada" do
    mexico = Sucursal.create!(codigo: "DFM", nombre: "DF México", ubicacion: nil, recibe_carga: true, activo: true,
                              codigo_recepcion_prefix: "RDF")
    assert_not_includes DireccionesDelCasillero.new(@juan).bloques.map(&:titulo), "DF México"

    mexico.update!(direccion: "Calle Falsa 123, CDMX")

    bloque = DireccionesDelCasillero.new(@juan).bloques.find { |b| b.titulo == "DF México" }
    assert_equal "Calle Falsa 123, CDMX", bloque.campos.to_h["Dirección"]
  end
end
