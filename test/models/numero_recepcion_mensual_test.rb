require "test_helper"

# PR-C6.40: el número de recepción lleva sucursal y mes.
#
# Yusef lo escribió a mano en la pregunta 17, rotulando cada parte:
#
#     R        MIA        26     12     ______________
#     prefijo  sucursal   año    mes    número correlativo recepción
#
# Y en el audio: *"sería sucursal donde se recibió, año y el mes… pero va a
# poner acá 12, el mes, y el número"*.
#
# **El cambio de fondo no es el `format`**: es que el correlativo reinicia
# **cada mes** y no cada 1° de enero. Eso vive en `NumeroRecepcionCounter`,
# cuya clave pasó de `(sucursal, año)` a `(sucursal, año, mes)`.
#
# El código de 3 letras ya existía (`Sucursal#codigo`), así que el
# `codigo_recepcion_prefix` viejo (`RM`, `RS`, `RH`) queda obsoleto.
class NumeroRecepcionMensualTest < ActiveSupport::TestCase
  setup do
    @miami = sucursales(:miami)
    NumeroRecepcionCounter.delete_all
  end

  test "el formato es el que escribio Yusef" do
    numero = Paquete.numero_recepcion_para(sucursal: @miami, fecha: Time.zone.local(2026, 12, 5))

    assert_equal "RMIA2612000001", numero
  end

  test "el correlativo sigue dentro del mismo mes" do
    diciembre = Time.zone.local(2026, 12, 5)

    3.times { Paquete.numero_recepcion_para(sucursal: @miami, fecha: diciembre) }

    assert_equal "RMIA2612000004", Paquete.numero_recepcion_para(sucursal: @miami, fecha: diciembre)
  end

  test "reinicia en 1 al cambiar de mes DENTRO del mismo ano" do
    # Es la razón de ser del cambio: antes reiniciaba una vez al año.
    #
    # Los dos meses van dentro del **mismo año** a propósito. Cruzando de
    # diciembre a enero el número también reiniciaría con el contador anual
    # viejo, así que ese caso no distingue nada — el primer intento de este
    # test pasaba con el bug puesto.
    2.times { Paquete.numero_recepcion_para(sucursal: @miami, fecha: Time.zone.local(2026, 8, 31)) }

    septiembre = Paquete.numero_recepcion_para(sucursal: @miami, fecha: Time.zone.local(2026, 9, 1))

    assert_equal "RMIA2609000001", septiembre
  end

  test "dos sucursales no comparten contador" do
    sps = sucursales(:zeron_sps)
    fecha = Time.zone.local(2026, 8, 10)

    a = Paquete.numero_recepcion_para(sucursal: @miami, fecha: fecha)
    b = Paquete.numero_recepcion_para(sucursal: sps, fecha: fecha)

    assert_equal "RMIA2608000001", a
    assert_equal "RSPS2608000001", b
  end

  test "el paquete lo genera solo al guardarse" do
    p = Paquete.create!(tracking: "1Z999MES0001", cliente: clientes(:juan), sucursal: @miami)
    fecha = p.fecha_recibido_miami

    assert_equal format("RMIA%02d%02d000001", fecha.year % 100, fecha.month), p.numero_recepcion
  end

  test "las cajas de un split comparten el numero madre" do
    # El número madre sale del mismo generador, así que si se separan los dos
    # caminos las cajas dejan de compartirlo — que es lo que este proyecto ya
    # arrastró con otras duplicaciones.
    numero = Paquete.generate_numero_recepcion_madre(sucursal: @miami, attrs: {})

    assert_match(/\ARMIA\d{4}000001\z/, numero)
  end
end
