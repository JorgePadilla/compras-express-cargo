require "test_helper"

# PR-10.g: los precios reales de Yusef, verificados sobre los datos que la
# tarea siembra — no sobre fixtures inventadas. Si alguien toca la tabla, estos
# tests dicen exactamente qué se le cobra distinto al cliente.
#
# Fuente: `precios por categoria 2026.xlsx`, hoja PROPUESTA.
class TarifaPropuesta2026Test < ActiveSupport::TestCase
  setup do
    TarifasPropuesta2026.sembrar!
    @tasa = CurrencyAware.tasa_vigente          # 24.85
  end

  # ── Precio de lista, escalonado ─────────────────────────────────────────

  test "CER de 0.5 lb cobra el minimo, que con ISV da L.200 exactos" do
    cobro = cobrar("cer", 0.5)

    assert cobro[:aplico_minimo]
    assert_equal "LPS", cobro[:moneda]
    assert_equal BigDecimal("173.91"), cobro[:subtotal]

    tarifa = resolver("cer", 0.5)
    assert_equal BigDecimal("200.0"), tarifa.minimo_monto_con_isv
  end

  test "CER de 10 lb cobra 10 x 4.50" do
    cobro = cobrar("cer", 10)

    assert_not cobro[:aplico_minimo]
    assert_equal "USD", cobro[:moneda]
    assert_equal BigDecimal("45.00"), cobro[:subtotal]
  end

  test "CER de 75 lb baja al escalon de 4.00" do
    assert_equal BigDecimal("4.00"), resolver("cer", 75).precio_libra
    assert_equal BigDecimal("300.00"), cobrar("cer", 75)[:subtotal]
  end

  test "CER de 200 lb usa el ultimo escalon, 3.50" do
    assert_equal BigDecimal("3.50"), resolver("cer", 200).precio_libra
    assert_equal BigDecimal("700.00"), cobrar("cer", 200)[:subtotal]
  end

  # El tramo chico del maritimo es un recargo: arranca en 4.50 y recién
  # pasadas las 3 libras baja al precio normal de 2.50.
  test "CEM cobra 4.50 hasta 3 lb y 2.50 despues" do
    assert_equal BigDecimal("4.50"), resolver("cem", 2).precio_libra
    assert_equal BigDecimal("2.50"), resolver("cem", 50).precio_libra
  end

  test "CEM no deja huecos entre 100 y 101 lb" do
    # En la hoja el corte dice "101", pero con pesos de media libra un paquete
    # de 100.5 se quedaría sin tarifa. Se toma el patrón de CER (100.5).
    assert_equal BigDecimal("2.20"), resolver("cem", 100.5).precio_libra
    assert_equal BigDecimal("2.50"), resolver("cem", 100).precio_libra
  end

  test "CKM recorre sus cinco escalones" do
    assert_equal BigDecimal("4.00"), resolver("ckm", 2).precio_libra
    assert_equal BigDecimal("2.50"), resolver("ckm", 10).precio_libra
    assert_equal BigDecimal("1.90"), resolver("ckm", 50).precio_libra
    assert_equal BigDecimal("1.75"), resolver("ckm", 150).precio_libra
    assert_equal BigDecimal("1.65"), resolver("ckm", 300).precio_libra
  end

  # ── Sobrecosto de Tegucigalpa ───────────────────────────────────────────

  test "CKM de 50 lb cuesta mas en Tegucigalpa que en SPS" do
    sps = sucursales(:zeron_sps)
    tgu = sucursales(:humuya_tgu)

    assert_equal BigDecimal("95.00"),  cobrar("ckm", 50, sucursal: sps)[:subtotal]
    assert_equal BigDecimal("100.00"), cobrar("ckm", 50, sucursal: tgu)[:subtotal]
  end

  test "el sobrecosto de Tegucigalpa solo aplica al escalon de 13.5 a 100" do
    # Es la única fila que la hoja diferencia por sucursal; el resto de los
    # escalones cae en la tarifa general.
    tgu = sucursales(:humuya_tgu)
    assert_equal BigDecimal("1.75"), resolver("ckm", 150, sucursal: tgu).precio_libra
    assert_nil resolver("ckm", 150, sucursal: tgu).sucursal_id
  end

  test "Shein paga mas caro el maritimo en Tegucigalpa" do
    cliente = cliente_con_categoria("Shein")

    assert_equal BigDecimal("1.75"),
                 resolver("cem", 10, cliente: cliente, sucursal: sucursales(:zeron_sps)).precio_libra
    assert_equal BigDecimal("1.90"),
                 resolver("cem", 10, cliente: cliente, sucursal: sucursales(:humuya_tgu)).precio_libra
  end

  # ── Mínimos ─────────────────────────────────────────────────────────────

  test "EXPRESS tiene minimo de 10 dolares, no de lempiras" do
    cobro = cobrar("express", 1)

    assert cobro[:aplico_minimo]
    assert_equal "USD", cobro[:moneda]
    assert_equal BigDecimal("10.00"), cobro[:subtotal]
    # A 1.34 lb el cálculo ya supera el mínimo y deja de aplicar.
    assert_not cobrar("express", 5)[:aplico_minimo]
  end

  test "CKA aplica el minimo general de L.173.91" do
    cobro = cobrar("cka", 1)

    assert cobro[:aplico_minimo]
    assert_equal BigDecimal("173.91"), cobro[:subtotal]
  end

  test "la categoria Sin Cobro Minimo cobra el peso real por chico que sea" do
    cliente = cliente_con_categoria("Sin Cobro Mínimo")
    cobro   = cobrar("cer", 0.5, cliente: cliente)

    assert_not cobro[:aplico_minimo]
    assert_equal BigDecimal("2.25"), cobro[:subtotal]
  end

  # ── Categorías ──────────────────────────────────────────────────────────

  test "Personal CEC paga 3.00 la libra en CKA con minimo de 3 dolares" do
    cliente = cliente_con_categoria("Personal CEC")

    assert_equal BigDecimal("30.00"), cobrar("cka", 10, cliente: cliente)[:subtotal]

    chico = cobrar("cka", 0.5, cliente: cliente)
    assert chico[:aplico_minimo]
    assert_equal "USD", chico[:moneda]
    assert_equal BigDecimal("3.00"), chico[:subtotal]
  end

  test "un minimo en 0 en la hoja significa sin minimo, no minimo de cero" do
    # CEM y CKM de Clientes Amigos vienen con MINIMO = 0.
    tarifa = resolver("cem", 10, cliente: cliente_con_categoria("Clientes Amigos"))

    assert_nil tarifa.minimo_monto
    assert_not cobrar("cem", 1, cliente: cliente_con_categoria("Clientes Amigos"))[:aplico_minimo]
  end

  test "Familia y Revendedores existen como categoria pero caen al precio de lista" do
    %w[Familia Revendedores].each do |nombre|
      assert CategoriaPrecio.exists?(nombre: nombre), "falta la categoría #{nombre}"

      tarifa = resolver("cer", 10, cliente: cliente_con_categoria(nombre))
      assert_equal "Lista", tarifa.nivel
      assert_equal BigDecimal("4.50"), tarifa.precio_libra
    end
  end

  test "la tarifa del cliente gana sobre la de su categoria" do
    cliente = cliente_con_categoria("Shein")
    Tarifa.create!(tipo_envio: tipo_envio("cer"), cliente: cliente,
                   desde_libras: 0, precio_libra: 2.00, moneda: "USD")

    assert_equal BigDecimal("2.00"), resolver("cer", 10, cliente: cliente).precio_libra
  end

  # ── Consistencia del sembrado ───────────────────────────────────────────

  test "resembrar no duplica filas" do
    antes = Tarifa.count
    resultado = TarifasPropuesta2026.sembrar!

    assert_equal antes, Tarifa.count
    assert_equal 0, resultado[:creadas]
    assert_equal 0, resultado[:actualizadas]
  end

  test "los escalones cubren cualquier peso sin huecos ni solapes" do
    %w[cer cka express cem ckm].each do |codigo|
      escalones = Tarifa.where(tipo_envio: tipo_envio(codigo), categoria_precio_id: nil,
                               sucursal_id: nil, cliente_id: nil, proveedor_id: nil)
                        .order(:desde_libras)

      assert_equal BigDecimal("0"), escalones.first.desde_libras, "#{codigo} no arranca en 0"
      assert_nil escalones.last.hasta_libras, "#{codigo} no tiene escalón abierto al final"

      escalones.each_cons(2) do |actual, siguiente|
        assert_equal actual.hasta_libras, siguiente.desde_libras,
                     "#{codigo}: hueco o solape entre #{actual.escalon_label} y #{siguiente.escalon_label}"
      end
    end
  end

  test "el precio_libra del tipo de envio queda alineado con el precio de lista" do
    # Es el fallback cuando no hay tarifa cargada. Si cobra distinto que la
    # tarifa, el mismo paquete vale dos cosas según por dónde entre.
    { "cer" => "4.50", "cka" => "4.00", "express" => "7.50",
      "cem" => "2.50", "ckm" => "1.90" }.each do |codigo, esperado|
      assert_equal BigDecimal(esperado), tipo_envio(codigo).reload.precio_libra,
                   "#{codigo} desalineado"
    end
  end

  test "todas las tarifas sembradas quedan activas y en dolares" do
    sembradas = Tarifa.where(notas: TarifasPropuesta2026::NOTA)

    assert_operator sembradas.count, :>=, 38
    assert_empty sembradas.where(activo: false)
    assert_empty sembradas.where.not(moneda: "USD")
  end

  private

  def tipo_envio(codigo)
    TipoEnvio.find_by!(codigo: codigo)
  end

  def resolver(codigo, peso, cliente: nil, sucursal: nil)
    Tarifa.resolver(tipo_envio: tipo_envio(codigo), peso: peso,
                    cliente: cliente, sucursal: sucursal)
  end

  def cobrar(codigo, peso, cliente: nil, sucursal: nil)
    resolver(codigo, peso, cliente: cliente, sucursal: sucursal).cobro_para(peso)
  end

  def cliente_con_categoria(nombre)
    @clientes ||= {}
    @clientes[nombre] ||= Cliente.create!(
      nombre: "Prueba #{nombre}",
      categoria_precio: CategoriaPrecio.find_by!(nombre: nombre)
    )
  end
end
