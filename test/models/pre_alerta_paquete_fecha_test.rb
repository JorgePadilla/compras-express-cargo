require "test_helper"

# PR: la fecha se ve en el campo, no solo se guarda.
#
# Jorge, en `/pre_alertas/new`: *"pongamos la fecha que se está haciendo, por
# defecto en el campo"*.
#
# `set_default_fecha` ya la ponía —o sea que se guardaba bien— pero el campo
# salía vacío: el operario no sabía qué fecha iba a quedar, y el dato parecía
# faltante.
class PreAlertaPaqueteFechaTest < ActiveSupport::TestCase
  test "una fila nueva ya trae la fecha de hoy, sin guardar nada" do
    assert_equal Date.current, PreAlertaPaquete.new.fecha
  end

  test "la fila que se construye desde la pre-alerta tambien" do
    # Es la que pinta el controller en `/pre_alertas/new`.
    pa = PreAlerta.new(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer))

    assert_equal Date.current, pa.pre_alerta_paquetes.build.fecha
  end

  test "si el operario pone otra fecha, manda la suya" do
    otra = Date.new(2020, 1, 5)

    assert_equal otra, PreAlertaPaquete.new(fecha: otra).fecha
  end

  test "un registro viejo con fecha nula se sigue leyendo nulo" do
    # El default es para lo NUEVO. Si aplicara al leer, cualquier consulta le
    # inventaría a un registro viejo una fecha de hoy que nunca tuvo — y eso
    # después se imprime en el Warehouse Receipt como si fuera un dato.
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    pap.update_column(:fecha, nil)

    assert_nil PreAlertaPaquete.find(pap.id).fecha
  end

  test "la red del before_validation sigue puesta" do
    # Si alguien manda la fecha en blanco a propósito —un request armado a mano,
    # un import— igual entra con la de hoy.
    pap = pre_alerta_paquetes(:pap_sin_vincular)
    pap.fecha = nil
    pap.valid?

    assert_equal Date.current, pap.fecha
  end
end
