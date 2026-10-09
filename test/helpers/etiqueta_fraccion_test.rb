require "test_helper"

# El «1 de 2» de la etiqueta.
#
# Tiene dos decisiones encima, de dos personas, y las dos con razón sobre casos
# distintos.
#
# `A7-21` — Yusef, sobre el empaque:
#
#   > *"La etiqueta solo lleva el número, no lleva el uno de dos ni de tres,
#   >  porque no estamos seguros cuántas estamos empacando."*
#   > *"Cuando menos acordás: hey, me salieron cuatro en vez de cinco."*
#
# 2026-08-19 — Jorge, sobre una etiqueta de un envío de dos cajas:
#
#   > *"El 1 está bien, pero aquí yo mandé 2. Cuando manda más de una debe
#   >  llevar el 1/2."*
#
# La regla que los concilia: la fracción sale **solo cuando el total está
# grabado**. Al recibir se fija antes de imprimir —el operario cargó las cajas o
# contestó cuántas—; al empacar va apareciendo, y ahí sale el número solo.
class EtiquetaFraccionTest < ActionView::TestCase
  include EtiquetaHelper

  test "un envio de dos cajas dice 1/2 y 2/2" do
    cajas = crear_split(2)

    assert_equal "1/2", etiqueta_fraccion(cajas.first)
    assert_equal "2/2", etiqueta_fraccion(cajas.second)
  end

  test "un bulto solo sigue sin fraccion" do
    # Un "1/1" en una caja única es ruido: no hay a qué compararlo.
    assert_equal "1", etiqueta_fraccion(paquete_simple)
  end

  test "sin total grabado sale el numero solo" do
    # El caso de Yusef: si nadie fijó cuántas son, inventar un total manda a
    # buscar un bulto que puede no existir.
    suelto = paquete_simple
    suelto.numero_caja = 2
    suelto.cantidad_paquetes = nil

    assert_equal "2", etiqueta_fraccion(suelto)
  end

  test "la fraccion sale impresa en la etiqueta" do
    # El helper puede estar bien y la vista no llamarlo — que es la forma en que
    # este repo se rompe. Se mira el papel, no el método.
    cajas = crear_split(2)
    html = render(partial: "paquetes/etiqueta", locals: { paquete: cajas.first })

    assert_includes html, "1/2"
  end

  test "el codigo de barras sigue llevando su sufijo, que es otra cosa" do
    # `RM…-1` es lo que permite rebajar inventario caja por caja en San Pedro.
    # Son dos cosas distintas en dos lugares distintos de la etiqueta.
    cajas = crear_split(2)

    assert_match(/-1\z/, etiqueta_codigo_barras(cajas.first))
    assert_match(/-2\z/, etiqueta_codigo_barras(cajas.second))
  end

  private

  def paquete_simple
    Paquete.new(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                tracking: "1ZFRACCION0001", descripcion: "x", estado: "recibido_miami",
                sucursal: sucursales(:humuya_tgu))
  end

  def crear_split(total)
    Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
               tracking: "1ZFRACCION#{total}CAJAS", descripcion: "Varias cajas",
               estado: "recibido_miami", user: users(:admin),
               sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:humuya_tgu) },
      total_cajas: total, por_caja: { 1 => { peso: 10 }, 2 => { peso: 20 } }
    )
  end
end
