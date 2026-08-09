require "test_helper"

# PR-C6.19: el informe de impacto del redondeo a media libra.
#
# Ya no es una compuerta — Yusef dio la orden sin pedir el número antes
# ("préndanlo ya", RP-03). Sigue sirviendo para verificar **después** de
# activar, para darle evidencia al contador, y para ser el insumo con el que
# por fin revise la hoja 2 del Excel (RP-16: "no ha revisado").
#
# Lo importante del diseño: usa **el motor real** (`Tarifa.resolver`,
# `cobro_para`, `peso_facturable`), no una reimplementación de la regla. Si el
# simulador y la facturación difirieran, el informe mentiría y sería peor que
# no tenerlo.
class SimuladorRedondeoTest < ActiveSupport::TestCase
  setup do
    @cer = tipo_envios(:cer)
    Tarifa.destroy_all
    Configuracion.set("tasa_cambio", "27.10", tipo: "decimal", categoria: "moneda")
    # Los dos escalones reales de CER, con la frontera en 50.5.
    @caro   = escalon(desde: 0,    hasta: 50.5, precio: 4.50, minimo: 173.91)
    @barato = escalon(desde: 50.5, hasta: nil,  precio: 4.00, minimo: 173.91)
  end

  test "un peso que ya viene en media libra no se mueve" do
    fila = simular(10.0)

    assert_equal :sin_cambio, fila.segmento
    assert_equal 0, fila.delta
  end

  test "la fraccion dentro de la tolerancia BAJA, a favor del cliente" do
    # 10.05 − 0.09 = 9.96 → sube al siguiente múltiplo de 0.5 = 10.0.
    # Antes: 10.05 × 4.50 = $45.23 → L.1225.73
    # Ahora: 10.00 × 4.50 = $45.00 → L.1219.50
    fila = simular(10.05)

    assert_equal :baja, fila.segmento
    assert_equal 10.0, fila.peso_redondeado.to_f
    assert_equal(-6.23, fila.delta.to_f.round(2))
  end

  test "la fraccion que redondea hacia arriba SUBE" do
    # 10.30 → 10.5. Antes $46.35 (L.1256.09), ahora $47.25 (L.1280.48).
    fila = simular(10.30)

    assert_equal :sube, fila.segmento
    assert_equal 10.5, fila.peso_redondeado.to_f
    assert_equal 24.39, fila.delta.to_f.round(2)
  end

  test "el que cruza la frontera BAJA fuerte" do
    # El caso que PR-C6.18 vino a arreglar: 50.2 lb redondea a 50.5, y 50.5
    # cae en el tramo de $4.00.
    #   Antes: 50.2 × 4.50 = $225.90 → L.6121.89
    #   Ahora: 50.5 × 4.00 = $202.00 → L.5474.20
    fila = simular(50.2)

    assert_equal :frontera, fila.segmento
    assert_equal(-647.69, fila.delta.to_f.round(2))
  end

  test "el que cae en el minimo no cambia" do
    # 1.05 lb → $4.73 y $4.50; los dos por debajo del mínimo (173.91/27.10 =
    # $6.42), así que los dos cobran L.173.91 + el ISV lo pone la factura.
    fila = simular(1.05)

    assert_equal :minimo, fila.segmento
    assert_equal 0, fila.delta
  end

  test "el resumen agrupa por segmento y no promedia todo junto" do
    # El impacto NO es uniforme: promediarlo todo escondería que unos bajan
    # fuerte mientras la mayoría sube un poquito.
    sim = SimuladorRedondeo.new(paquetes: [ paquete(10.30), paquete(10.05), paquete(50.2) ])

    segmentos = sim.resumen.map { |r| r[:paquetes] }
    assert_equal 3, segmentos.sum
    assert_equal 3, sim.resumen.size, "juntó segmentos que se comportan distinto"
  end

  test "no escribe absolutamente nada" do
    # Es la garantía del PR: se corre en staging contra datos reales.
    p1 = paquete(10.30)
    sim = SimuladorRedondeo.new(paquetes: [ p1 ])

    assert_no_difference [ "PaperTrail::Version.count", "Paquete.count", "Tarifa.count" ] do
      sim.filas
      sim.resumen
      sim.total
    end
    assert_nil Tarifa.first.incremento_libras, "el simulador activó el redondeo de verdad"
    assert_equal 10.30, p1.reload.peso_cobrar.to_f
  end

  test "el paquete sin tarifa resoluble se salta, no revienta" do
    Tarifa.destroy_all

    assert_empty SimuladorRedondeo.new(paquetes: [ paquete(10.30) ]).filas
  end

  test "el paquete sin peso a cobrar se salta" do
    p1 = paquete(10.30)
    p1.update_columns(peso_cobrar: nil)

    assert_empty SimuladorRedondeo.new(paquetes: [ p1.reload ]).filas
  end

  private

  def escalon(desde:, hasta:, precio:, minimo:)
    Tarifa.create!(
      tipo_envio: @cer, desde_libras: desde, hasta_libras: hasta,
      precio_libra: precio, moneda: "USD", activo: true,
      aplica_minimo: true, minimo_monto: minimo, minimo_moneda: "LPS"
    )
  end

  def paquete(peso)
    p = Paquete.create!(
      tracking: "SIM#{SecureRandom.hex(4)}", cliente: clientes(:juan),
      tipo_envio: @cer, descripcion: "Prueba", peso: peso,
      estado: "recibido_miami", user: users(:digitador)
    )
    # `peso_cobrar` es derivado (max entre real y volumétrico); se fija directo
    # para que el caso de prueba sea el peso exacto que se quiere simular.
    p.update_columns(peso_cobrar: peso)
    p.reload
  end

  def simular(peso)
    SimuladorRedondeo.new(paquetes: [ paquete(peso) ]).filas.first
  end
end
