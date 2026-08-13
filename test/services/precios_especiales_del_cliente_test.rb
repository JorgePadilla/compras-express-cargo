require "test_helper"

# El megacuadro de A7-26 · PR-C7.15.
#
# Yusef: *"ese precio especial para un cliente debería estar en el cliente…
# entro al cliente y le pongo el precio especial"*, *"le doy descuento en CER y
# en CEM, pero no le doy descuento en EXPRESS"*.
#
# Es una **vista sobre `tarifas`**, no una tabla nueva: escribe las filas de
# nivel cliente, que ya son el primer nivel de `Tarifa.resolver`.
class PreciosEspecialesDelClienteTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @cer     = tipo_envios(:cer)
    @cem     = tipo_envios(:cem)
    Tarifa.delete_all
  end

  def cuadro = PreciosEspecialesDelCliente.new(@cliente)

  def propia(tipo_envio = @cer)
    Tarifa.find_by(cliente_id: @cliente.id, tipo_envio_id: tipo_envio.id)
  end

  # ── La tabla de decisión, fila por fila ──────────────────────────────────

  test "precio con valor y sin fila: la crea" do
    assert_difference "Tarifa.count", 1 do
      assert cuadro.aplicar(@cer.id.to_s => { precio: "3.50" })
    end

    t = propia
    assert_equal BigDecimal("3.50"), t.precio_libra
    assert_equal "USD", t.moneda
    assert_equal 0, t.desde_libras
    assert_nil t.hasta_libras, "la fila del cuadro es plana: el escalonado se edita en /servicios"
  end

  test "precio con valor y fila plana: la actualiza en vez de duplicarla" do
    cuadro.aplicar(@cer.id.to_s => { precio: "3.50" })

    assert_no_difference "Tarifa.count" do
      assert cuadro.aplicar(@cer.id.to_s => { precio: "3.25" })
    end

    assert_equal BigDecimal("3.25"), propia.precio_libra
  end

  # Misma semántica que PR-C7.14: lo que se ve manda, y vaciar un campo
  # **quita**, no "deja como estaba".
  test "precio vacio y fila plana: le quita la excepcion" do
    cuadro.aplicar(@cer.id.to_s => { precio: "3.50" })

    assert_difference "Tarifa.count", -1 do
      assert cuadro.aplicar(@cer.id.to_s => { precio: "" })
    end

    assert_nil propia
  end

  test "precio vacio y sin fila: no pasa nada" do
    assert_no_difference "Tarifa.count" do
      assert cuadro.aplicar(@cer.id.to_s => { precio: "" })
    end
  end

  # Un cuadro de una celda por servicio no puede representar una escalera. Si
  # alguien construyó tramos en /servicios, un formulario viejo no los aplasta.
  test "escalonado: rechaza con error y no toca los tramos" do
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, desde_libras: 0, hasta_libras: 50,
                   precio_libra: 4.00, moneda: "USD")
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, desde_libras: 50,
                   precio_libra: 3.50, moneda: "USD")

    c = cuadro
    assert_no_difference "Tarifa.count" do
      assert_not c.aplicar(@cer.id.to_s => { precio: "1.00" })
    end

    assert_match(/tramos/i, c.errores.to_sentence)
    assert_match(/Tabla de Servicios/i, c.errores.to_sentence)
  end

  test "un minimo sin precio no crea nada" do
    assert_no_difference "Tarifa.count" do
      assert cuadro.aplicar(@cer.id.to_s => { precio: "", minimo_con_isv: "200" })
    end
  end

  # ── El mínimo, en el idioma de Yusef ─────────────────────────────────────

  test "el minimo se teclea con ISV y se guarda neto" do
    cuadro.aplicar(@cer.id.to_s => { precio: "3.50", minimo_con_isv: "5.75", aplica_minimo: "1" })

    t = propia
    assert_equal BigDecimal("5.00"), t.minimo_monto, "5.75 con 15% de ISV son 5.00 netos"
    assert_equal "USD", t.minimo_moneda, "el cuadro entero habla en dólares"
    assert t.aplica_minimo
  end

  test "destildar cobrar minimo lo desactiva sin borrar el monto" do
    cuadro.aplicar(@cer.id.to_s => { precio: "3.50", minimo_con_isv: "5.75", aplica_minimo: "0" })

    assert_not propia.aplica_minimo
    assert_equal BigDecimal("5.00"), propia.minimo_monto
  end

  # ── Media negociación aplicada es peor que ninguna ───────────────────────

  test "si una celda falla no se aplica ninguna" do
    c = cuadro

    assert_no_difference "Tarifa.count" do
      assert_not c.aplicar(
        @cer.id.to_s => { precio: "3.50" },
        @cem.id.to_s => { precio: "-1" }   # inválido: numericality >= 0
      )
    end

    assert_nil propia(@cer), "la primera celda se revirtió con la segunda"
  end

  # ── Lo que se pinta ──────────────────────────────────────────────────────

  test "paga hoy ignora el precio especial: es contra lo que se negocia" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")   # lista
    cuadro.aplicar(@cer.id.to_s => { precio: "3.50" })

    fila = cuadro.filas([ @cer ]).first

    assert_equal BigDecimal("3.50"), fila.vigente.precio_libra, "lo que paga de verdad"
    assert_equal BigDecimal("4.50"), fila.sin_excepcion.precio_libra, "contra lo que se compara"
    assert_equal "Lista", fila.sin_excepcion.nivel
    assert_equal(-22, fila.descuento_pct)
  end

  test "sin excepcion no hay porcentaje que mostrar" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    assert_nil cuadro.filas([ @cer ]).first.descuento_pct
  end

  test "la fila sabe si el servicio esta escalonado" do
    Tarifa.create!(cliente: @cliente, tipo_envio: @cer, desde_libras: 0, hasta_libras: 50,
                   precio_libra: 4.00, moneda: "USD")

    assert cuadro.filas([ @cer ]).first.escalonado?
  end

  # Yusef: "es lo que le creamos al cliente, **cuando creamos el cliente**".
  test "funciona con un cliente sin guardar, para el formulario de alta" do
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    fila = PreciosEspecialesDelCliente.new(Cliente.new).filas([ @cer ]).first

    assert_nil fila.propia
    assert_equal BigDecimal("4.50"), fila.sin_excepcion.precio_libra,
                 "un cliente sin id no tiene tarifas propias; sale el precio de lista"
  end

  # ── Lo que hace que el cuadro no sea decorativo ──────────────────────────

  test "el precio del cuadro le gana al grupo, y quitarlo lo devuelve al grupo" do
    grupo = categoria_precios(:regular)
    @cliente.update!(categoria_precio: grupo)
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")                    # lista
    Tarifa.create!(tipo_envio: @cer, categoria_precio: grupo, precio_libra: 4.00, moneda: "USD")

    cuadro.aplicar(@cer.id.to_s => { precio: "3.50" })
    elegida = Tarifa.resolver(tipo_envio: @cer, peso: 10, cliente: @cliente.reload)
    assert_equal BigDecimal("3.50"), elegida.precio_libra
    assert_equal "Cliente", elegida.nivel

    cuadro.aplicar(@cer.id.to_s => { precio: "" })
    elegida = Tarifa.resolver(tipo_envio: @cer, peso: 10, cliente: @cliente.reload)
    assert_equal BigDecimal("4.00"), elegida.precio_libra
    assert_equal "Grupo", elegida.nivel
  end

  # `ignorar_precio_del_cliente` no puede saltarse también el grupo: es lo que
  # hace que la columna "paga hoy" diga la verdad para un cliente con grupo.
  test "ignorar el precio del cliente deja el nivel del grupo en pie" do
    grupo = categoria_precios(:regular)
    @cliente.update!(categoria_precio: grupo)
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")
    Tarifa.create!(tipo_envio: @cer, categoria_precio: grupo, precio_libra: 4.00, moneda: "USD")
    Tarifa.create!(tipo_envio: @cer, cliente: @cliente, precio_libra: 3.50, moneda: "USD")

    sin = Tarifa.resolver(tipo_envio: @cer, peso: 10, cliente: @cliente.reload,
                          ignorar_precio_del_cliente: true)

    assert_equal BigDecimal("4.00"), sin.precio_libra
    assert_equal "Grupo", sin.nivel
  end
end
