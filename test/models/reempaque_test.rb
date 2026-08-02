require "test_helper"

class ReempaqueTest < ActiveSupport::TestCase
  test "al crear toma snapshot de las dimensiones actuales del paquete" do
    paquete = paquetes(:recibido)
    paquete.update!(alto: 20, largo: 30, ancho: 15, peso: 10)

    r = Reempaque.create!(
      paquete: paquete,
      alto_despues: 10, largo_despues: 15, ancho_despues: 10, peso_despues: 8
    )

    assert_equal 20, r.alto_antes
    assert_equal 30, r.largo_antes
    assert_equal 15, r.ancho_antes
    assert_equal 10, r.peso_antes
  end

  test "actualiza las dimensiones del paquete a los valores nuevos" do
    paquete = paquetes(:recibido)
    paquete.update!(alto: 20, largo: 30, ancho: 15, peso: 10)

    Reempaque.create!(
      paquete: paquete,
      alto_despues: 10, largo_despues: 15, ancho_despues: 10, peso_despues: 8
    )

    paquete.reload
    assert_equal 10, paquete.alto
    assert_equal 15, paquete.largo
    assert_equal 10, paquete.ancho
    assert_equal 8, paquete.peso
  end

  test "calcula peso volumetrico antes y despues" do
    r = Reempaque.new(
      alto_antes: 20, largo_antes: 30, ancho_antes: 15,
      alto_despues: 10, largo_despues: 15, ancho_despues: 10
    )
    assert_equal 54.22, r.peso_volumetrico_antes
    assert_equal 9.04, r.peso_volumetrico_despues
  end

  test "ahorro volumetrico es la diferencia" do
    r = reempaques(:reempaque_inicial)
    assert_equal 45.18, r.ahorro_volumetrico
  end

  test "ahorro peso cobrar usa max(real, volumetrico)" do
    r = reempaques(:reempaque_inicial)
    # antes: peso_real=10, peso_vol=54.22 → peso_cobrar_antes = 54.22
    # despues: peso_real=8, peso_vol=9.04 → peso_cobrar_despues = 9.04
    assert_equal 54.22, r.peso_cobrar_antes
    assert_equal 9.04, r.peso_cobrar_despues
    assert_equal 45.18, r.ahorro_peso_cobrar
  end

  test "vincula y completa la tarea opcional" do
    paquete = paquetes(:recibido)
    paquete.update!(alto: 20, largo: 30, ancho: 15, peso: 10)
    tarea = paquete.tareas.create!(titulo: "Reempaque solicitado")
    user = users(:digitador)

    r = Reempaque.create!(
      paquete: paquete,
      tarea: tarea,
      hecho_por: user,
      alto_despues: 10, largo_despues: 15, ancho_despues: 10, peso_despues: 8
    )

    assert_predicate tarea.reload, :realizada?
    assert_equal user, tarea.completado_por
  end

  test "valida presencia de dimensiones despues" do
    r = Reempaque.new(paquete: paquetes(:recibido))
    assert_not r.valid?
    assert_includes r.errors.attribute_names, :alto_despues
    assert_includes r.errors.attribute_names, :largo_despues
    assert_includes r.errors.attribute_names, :ancho_despues
    assert_includes r.errors.attribute_names, :peso_despues
  end
end
