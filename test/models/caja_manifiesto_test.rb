require "test_helper"

# C21-04 · Las casas del manifiesto.
#
# Yusef, mostrando la bodega por cámara: *"solo vamos a etiquetar la caja ahí
# empacada"*. Es la entidad que `docs/06` daba por faltante desde la
# Conversación 5 —*"falta la entidad de «caja empacada» entre `Paquete` y
# `Manifiesto`"*— y de la que cuelga todo el resto del módulo.
class CajaManifiestoTest < ActiveSupport::TestCase
  setup do
    @manifiesto = manifiestos(:creado)
    @mini_d = TamanoCaja.create!(nombre: "Mini D", alto: 46, largo: 43, ancho: 50)
  end

  # El número exacto que muestra la pantalla del sistema viejo para 46×43×50.
  # Es la mejor prueba de que el divisor es el correcto: sale del mismo
  # `VolumetricoCalculator` que ya usa todo el sistema.
  test "el volumen de 46×43×50 da 595.78, que es lo que muestra la pantalla vieja" do
    caja = @manifiesto.cajas.create!(tamano_caja: @mini_d, peso: 131)

    assert_equal 595.78, caja.volumen.to_f
  end

  test "elegir un tamaño copia sus medidas" do
    caja = @manifiesto.cajas.create!(tamano_caja: @mini_d, peso: 131)

    assert_equal [ 46, 43, 50 ], [ caja.alto.to_i, caja.largo.to_i, caja.ancho.to_i ]
    assert_equal "46x43x50", caja.medidas
  end

  # *"Ellos vienen y marcan EH y le modifican una medida, porque la cortan…
  # le decimos «EH cortada»."* El tamaño es punto de partida, no valor fijo.
  test "las medidas quedan editables después de elegir el tamaño — la EH cortada" do
    caja = @manifiesto.cajas.create!(tamano_caja: @mini_d, peso: 131)

    caja.update!(alto: 30)

    assert_equal 30, caja.reload.alto.to_i
    assert_equal @mini_d, caja.tamano_caja, "sigue siendo una Mini D, cortada"
    assert_equal (30 * 43 * 50 / 166.0).round(2), caja.volumen.to_f,
                 "el volumen tiene que seguir la medida real: es lo que el proveedor cobra"
  end

  # «Especificar» es uno de los diez tamaños y no tiene medidas.
  test "una caja sin tamaño se mide a mano" do
    caja = @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    assert_nil caja.tamano_caja
    assert_equal 16.29, caja.volumen.to_f, "el otro número del manifiesto impreso"
  end

  test "las letras van A, B, C — y el código cuelga del número del manifiesto" do
    a = @manifiesto.cajas.create!(peso: 1)
    b = @manifiesto.cajas.create!(peso: 1)

    assert_equal %w[A B], [ a.letra, b.letra ]
    assert_equal "#{@manifiesto.numero}-A", a.codigo
    assert_equal "#{@manifiesto.numero}-B", b.codigo
  end

  # Si la letra saliera de las filas vivas, borrar la última después de imprimir
  # su etiqueta y agregar otra reusaría la letra — y esa etiqueta, ya pegada a un
  # bulto, apuntaría a otra caja.
  test "borrar la última caja no le devuelve la letra a la siguiente" do
    @manifiesto.cajas.create!(peso: 1)
    b = @manifiesto.cajas.create!(peso: 1)
    b.destroy!

    tercera = @manifiesto.cajas.create!(peso: 1)

    assert_equal "C", tercera.letra, "la B ya se imprimió y se pegó a un bulto"
  end

  test "pasada la Z sigue como las columnas de una hoja de cálculo" do
    assert_equal "Z",  CajaManifiesto.letra_para(26)
    assert_equal "AA", CajaManifiesto.letra_para(27)
    assert_equal "AB", CajaManifiesto.letra_para(28)
  end

  test "dos manifiestos no se pisan los códigos" do
    otro = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ])

    a1 = @manifiesto.cajas.create!(peso: 1)
    a2 = otro.cajas.create!(peso: 1)

    assert_equal "A", a1.letra
    assert_equal "A", a2.letra
    assert_not_equal a1.codigo, a2.codigo
  end

  # *"Yo agarro el reporte y ellos me cobran [según] el reporte."* Con casas
  # armadas, el total del manifiesto es el de las casas — no la suma de los
  # paquetes sueltos.
  test "los totales del manifiesto salen de las cajas, que es lo que el proveedor cobra" do
    @manifiesto.cajas.create!(tamano_caja: @mini_d, peso: 131)
    @manifiesto.cajas.create!(alto: 13, largo: 13, ancho: 16, peso: 19)

    @manifiesto.recalculate_totals!

    assert_equal 2, @manifiesto.cantidad_bultos
    assert_equal 150, @manifiesto.peso_total.to_i
    assert_equal 612.07, @manifiesto.volumen_total.to_f
  end

  test "sin cajas, los totales siguen saliendo de los paquetes" do
    @manifiesto.recalculate_totals!

    assert_equal 0, @manifiesto.cantidad_bultos
  end

  # ── C23-01 · El número que acompaña a la letra ───────────────────────────
  #
  # *"Nosotros usamos la A y el 1… A 1, B el 2, C el 3."* · *"**Doble** porque
  #  la gente, a veces unos leen la A y otros leen el 1."*
  #
  # Va y vuelve: si `letra_para` y `numero_para` se separan, la etiqueta diría
  # `B1` — justo la confusión que la doble identificación viene a evitar.
  test "el número del bulto es la vuelta exacta de la letra" do
    [ 1, 2, 3, 25, 26, 27, 52, 53, 702, 703 ].each do |n|
      letra = CajaManifiesto.letra_para(n)
      assert_equal n, CajaManifiesto.numero_para(letra),
                   "#{letra} tendría que volver a ser #{n}"
    end
  end

  test "numero_bulto sale de la letra de la caja" do
    caja = manifiestos(:creado).cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)

    assert_equal CajaManifiesto.numero_para(caja.letra), caja.numero_bulto
  end

  test "numero_para no se traga basura" do
    assert_nil CajaManifiesto.numero_para(nil)
    assert_nil CajaManifiesto.numero_para("")
    assert_nil CajaManifiesto.numero_para("A1")
  end

  # ── C23-03 · Los pies cúbicos, sin tocar el ÷166 ─────────────────────────
  test "los pies cúbicos van por el mismo calculador, redondeando hacia arriba" do
    caja = manifiestos(:creado).cajas.create!(alto: 23, largo: 23, ancho: 36, peso: 131)

    # 23×23×36 = 19_044 in³ · ÷1728 = 11.02 → 12
    assert_equal 12, caja.pies_cubicos
    # Y el volumen del proveedor sigue siendo el ÷166, intacto.
    assert_in_delta 114.72, caja.volumen.to_f, 0.01
  end

  test "sin medidas no hay pies cúbicos" do
    caja = manifiestos(:creado).cajas.create!(peso: 5)

    assert_nil caja.pies_cubicos
  end
end
