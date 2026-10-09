require "test_helper"

# A7-25. Yusef encontró la duplicación navegando el sistema:
#
#   > "**Ya me acordé.** Yo hice categoría de precios al inicio, y después esta
#   >  es la que hice reciente. **Hay unas incongruencias.**"
#
# El detector encuentra las filas de categoría que la hoja de precios no
# declara. Importan porque en la cascada de `Tarifa.resolver` el nivel
# "categoría" **gana sobre el precio de lista**: no son un vestigio, son lo que
# se le cobra a esos clientes.
class TarifasHuerfanasTest < ActiveSupport::TestCase
  setup do
    @cer = tipo_envios(:cer)
    @ckm = tipo_envios(:ckm)
  end

  test "una categoria que la hoja no conoce sale como huerfana" do
    categoria = categoria_llamada("Regular")
    tarifa = crear_tarifa(categoria: categoria, tipo_envio: @cer, precio: 3.50)

    hallazgos = TarifasHuerfanas.detectar

    encontrada = hallazgos.find { |h| h.tarifa == tarifa }
    assert encontrada, "no detectó la fila de una categoría que la hoja no declara"
    assert_match(/no declara la categor/i, encontrada.motivo)
  end

  # A7-26. "Si es mayorista, se va a aplicar **solo a los marítimos**."
  # El backfill le dejó tarifa en los cinco servicios.
  test "mayorista en un aereo sale como huerfana" do
    mayorista = categoria_llamada("Mayorista")
    aereo = crear_tarifa(categoria: mayorista, tipo_envio: @cer, precio: 2.50)

    hallazgo = TarifasHuerfanas.detectar.find { |h| h.tarifa == aereo }

    assert hallazgo, "un mayorista con tarifa en un aéreo tiene que salir"
    assert_match(/solo aplica a mar/i, hallazgo.motivo)
  end

  test "mayorista en un maritimo NO es huerfana" do
    mayorista = categoria_llamada("Mayorista")
    maritimo = crear_tarifa(categoria: mayorista, tipo_envio: @ckm, precio: 1.50)

    assert_nil TarifasHuerfanas.detectar.find { |h| h.tarifa == maritimo },
               "el marítimo es justamente donde el mayorista sí aplica"
  end

  test "una categoria de la hoja con su servicio declarado no se toca" do
    amigos = categoria_llamada("Clientes Amigos")
    declarada = crear_tarifa(categoria: amigos, tipo_envio: @cer, precio: 4.20)

    assert_nil TarifasHuerfanas.detectar.find { |h| h.tarifa == declarada }
  end

  test "reporta que precio pagaria el cliente si la fila se borra" do
    categoria = categoria_llamada("Regular")
    lista = crear_tarifa(categoria: nil, tipo_envio: @cer, precio: 4.50)
    huerfana = crear_tarifa(categoria: categoria, tipo_envio: @cer, precio: 3.50)

    hallazgo = TarifasHuerfanas.detectar.find { |h| h.tarifa == huerfana }

    assert_equal lista.precio_libra, hallazgo.precio_si_se_borra,
                 "sin ese número nadie puede decidir si borrarla"
  end

  private

  # Las fixtures ya traen algunas categorías; se reusa la que exista para no
  # chocar con la unicidad del nombre.
  def categoria_llamada(nombre)
    CategoriaPrecio.find_or_create_by!(nombre: nombre)
  end

  def crear_tarifa(categoria:, tipo_envio:, precio:)
    Tarifa.create!(tipo_envio: tipo_envio, categoria_precio: categoria,
                   desde_libras: 0, hasta_libras: nil,
                   precio_libra: precio, moneda: "USD", activo: true)
  end
end
