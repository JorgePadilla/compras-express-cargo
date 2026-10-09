require "application_system_test_case"

# Que lo que el que recibe **tiene** que ver, le tape la pantalla.
#
# Yusef, 2026-08-19, señalando la franja donde esto salía como texto al costado:
#
#   > *"Estas informaciones ellos no las leen. Esto no lo van a leer, olvídate."*
#   > *"No te voy a mentir, Jorge: a puro huevos leen esto."*
#
# Va como system test porque un modal que aparece no lo puede ver ningún test de
# integración — y CI no corre `test/system`, así que la mitad del server tiene su
# propio archivo.
class AvisosAlEscanearTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    # La sesión en el tipo de las pre-alertas del archivo (CER), por `value`.
    # `first(...)` tomaba el primer botón —que ya no era CER— y desde
    # PR-C7.62 el conflicto de sesión sale antes que cualquier aviso: cinco de
    # los seis llevaban tiempo rojos sin que el CI los corriera.
    abrir_sesion_etiquetar(TipoEnvio.find(tipo_envios(:cer).id))
  end

  test "la retencion tapa la pantalla al escanear" do
    pap = pre_alertar("1ZAVISOSYS000001", retener: true)

    escanear(pap.tracking)

    assert_selector "[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "NO DESPACHAR"
    assert_text motivos_retencion(:danado).nombre
  end

  test "la nota del cliente también" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Con nota", estado: "pre_alerta",
                           notas_grupo: "Son regalos, no los abran")
    pa.pre_alerta_paquetes.create!(tracking: "1ZAVISOSYS000002", descripcion: "x")

    escanear("1ZAVISOSYS000002")

    assert_selector "[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "Son regalos, no los abran"
  end

  test "salen en fila, uno por cosa" do
    # Uno solo con todo adentro fue lo primero que pidió; Jorge argumentó que
    # cada uno necesita su propia respuesta y él aceptó.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Con las dos", estado: "pre_alerta",
                           notas_grupo: "Nota del grupo")
    pa.pre_alerta_paquetes.create!(tracking: "1ZAVISOSYS000003", descripcion: "x",
                                    retener_miami: true,
                                    motivo_retencion_ids: [ motivos_retencion(:danado).id ])

    escanear("1ZAVISOSYS000003")

    assert_selector "[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "NO DESPACHAR"

    click_on "Retenido, confirmado"

    assert_text "Nota del grupo", wait: 5
  end

  test "una tarea se puede marcar hecha desde el modal" do
    tarea = Tarea.create!(cliente: clientes(:juan), titulo: "Consolidar con lo de ayer",
                          estado: "pendiente")
    pap = pre_alertar("1ZAVISOSYS000004")

    escanear(pap.tracking)

    assert_selector "[data-etiquetar-target='avisoModal'][open]", wait: 5
    assert_text "Consolidar con lo de ayer"
    click_on "Se hizo"

    # El marcado va por `fetch`, así que hay que esperarlo: afirmar de una pasa
    # antes de que el POST llegue.
    esperar { tarea.reload.realizada? }
    assert_equal users(:digitador).id, tarea.completado_por_id
  end

  test "«todavía no» la deja pendiente" do
    tarea = Tarea.create!(cliente: clientes(:juan), titulo: "Pesarla otra vez",
                          estado: "pendiente")
    pap = pre_alertar("1ZAVISOSYS000005")

    escanear(pap.tracking)

    assert_selector "[data-etiquetar-target='avisoModal'][open]", wait: 5
    click_on "Todavía no"

    assert_equal "pendiente", tarea.reload.estado
  end

  test "un paquete sin nada no interrumpe" do
    # Si cada escaneo tapara la pantalla, en el segundo día dejarían de leerlos —
    # que es exactamente el problema que esto viene a arreglar.
    pap = pre_alertar("1ZAVISOSYS000006")

    escanear(pap.tracking)

    sleep 2
    assert_no_selector "[data-etiquetar-target='avisoModal'][open]"
  end

  private

  # Espera a que se cumpla algo que pasa por la red, sin quedarse colgado.
  def esperar(segundos = 5)
    limite = Time.current + segundos
    sleep 0.2 until yield || Time.current > limite
    assert yield, "no pasó lo que se esperaba en #{segundos}s"
  end

  def escanear(tracking)
    find("#paquete_tracking").set(tracking)
    find("#paquete_descripcion").click
  end

  def pre_alertar(tracking, retener: false)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciado", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(
      tracking: tracking, descripcion: "Lo que viene", retener_miami: retener,
      motivo_retencion_ids: retener ? [ motivos_retencion(:danado).id ] : []
    )
  end
end
