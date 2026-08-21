require "test_helper"

# Jorge, 2026-08-19: *"cuando estamos actualizando hay un comportamiento raro:
# cierro el modal y doy click en la forma y se vuelve a abrir el modal"*.
#
# Reproducido en el navegador: al entrar por `?paquete_id=`, el tracking viene
# puesto, y el primer blur del campo salía a preguntar si ya existía. Claro que
# existía — **era él**. Así que el operario que entró justamente a actualizar ese
# paquete recibía *"ya está en el sistema, ¿es una actualización?"* sobre el
# paquete que ya estaba actualizando, y el aviso volvía cada vez que el campo
# perdía el foco.
#
# `excluir_paquete_id` ya existía para esto: `PR-C6.44` lo agregó cuando el
# editor de pre-alertas se avisaba a sí mismo. El comentario del server decía
# *"/etiquetar nunca manda el parámetro"*, y era cierto mientras la pantalla solo
# diera de alta.
class ActualizarNoSeAvisaASiMismoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id
    }
    @paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               tracking: "1ZNOSEAVISA00001", descripcion: "x",
                               estado: "recibido_miami", user: users(:digitador),
                               sucursal_recepcion: sucursales(:miami))
  end

  test "excluyendose a si mismo, el tracking no figura como duplicado" do
    get check_tracking_paquetes_url(tracking: @paquete.tracking,
                                    excluir_paquete_id: @paquete.id), as: :json

    assert_not JSON.parse(response.body)["exists"], "se encontró a sí mismo"
  end

  test "sin excluir nada sigue avisando, que es lo correcto al dar de alta" do
    get check_tracking_paquetes_url(tracking: @paquete.tracking), as: :json

    assert JSON.parse(response.body)["exists"]
  end

  test "otro paquete con el mismo tracking sigue avisando" do
    # Excluirse a sí mismo no puede volverse ciego a los duplicados de verdad:
    # el courier recicla números y ese aviso es el que evita cobrar dos veces.
    otro = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           tracking: @paquete.tracking, descripcion: "el de verdad repetido",
                           estado: "recibido_miami", user: users(:digitador),
                           sucursal_recepcion: sucursales(:miami))

    get check_tracking_paquetes_url(tracking: @paquete.tracking,
                                    excluir_paquete_id: otro.id), as: :json

    assert JSON.parse(response.body)["exists"]
  end

  # ── Y las hermanas del mismo envío ──────────────────────────────────────
  #
  # Jorge, 2026-08-21: *"cuando estoy actualizando un tracking y le voy a dar
  # click a un campo, el modal lo sigue tirando… actualizar no está aún al 100"*.
  #
  # El arreglo de arriba excluía **la fila**, no **el envío**. Las cajas de un
  # split comparten tracking, así que al actualizar la Caja 1 el sistema
  # encontraba la Caja 2. Con un paquete suelto no pasaba, y por eso la prueba de
  # entonces lo dio por bueno.

  test "actualizando una caja de un split, sus hermanas no son un duplicado" do
    cajas = crear_split("1ZSPLITAVISO00001", 2)

    get check_tracking_paquetes_url(tracking: cajas.first.tracking,
                                    excluir_paquete_id: cajas.first.id), as: :json

    assert_not JSON.parse(response.body)["exists"], "encontró a su propia hermana"
  end

  test "pero un envío distinto con el mismo tracking sí avisa" do
    # Lo que el modal existe para atrapar: el courier recicla números. Se
    # distinguen por número de recepción, que es la clave del split.
    cajas = crear_split("1ZSPLITAVISO00002", 2)
    crear_split("1ZSPLITAVISO00002", 2)

    get check_tracking_paquetes_url(tracking: cajas.first.tracking,
                                    excluir_paquete_id: cajas.first.id), as: :json

    assert JSON.parse(response.body)["exists"], "se volvió ciego a los duplicados de verdad"
  end

  test "el conteo del modal no cuenta las hermanas propias" do
    # Decía «ya hay 3» cuando eran las dos cajas del operario más un ajeno.
    cajas = crear_split("1ZSPLITAVISO00003", 2)
    Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    tracking: "1ZSPLITAVISO00003", descripcion: "el ajeno",
                    estado: "recibido_miami", user: users(:digitador),
                    sucursal_recepcion: sucursales(:miami))

    get check_tracking_paquetes_url(tracking: cajas.first.tracking,
                                    excluir_paquete_id: cajas.first.id), as: :json

    assert_equal 1, JSON.parse(response.body)["count"]
  end

  test "el editor de pre-alertas sigue igual: un esperado no tiene envío" do
    # El otro consumidor de este parámetro, y el original (`PR-C6.44`). Un
    # paquete esperado no tiene número de recepción, así que excluye solo a sí
    # mismo — que es lo que siempre hizo.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "x", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1ZESPERADOAVISO1", descripcion: "x")

    get check_tracking_paquetes_url(tracking: pap.tracking,
                                    excluir_paquete_id: pap.paquete_id), as: :json

    assert_not JSON.parse(response.body)["exists"]
  end

  test "un id que no existe no revienta ni esconde nada" do
    otro = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           tracking: "1ZIDFANTASMA0001", descripcion: "x",
                           estado: "recibido_miami", user: users(:digitador),
                           sucursal_recepcion: sucursales(:miami))

    get check_tracking_paquetes_url(tracking: otro.tracking,
                                    excluir_paquete_id: 999_999_999), as: :json

    assert_response :success
    assert JSON.parse(response.body)["exists"]
  end

  test "la pantalla manda cuál se está actualizando" do
    get etiquetar_url(paquete_id: @paquete.id)

    assert_response :success
    assert_match(/data-etiquetar-actualizando-id-value="#{@paquete.id}"/, response.body)
  end

  test "al dar de alta no manda ninguno" do
    get etiquetar_url

    assert_match(/data-etiquetar-actualizando-id-value=""/, response.body)
  end

  test "las dos consultas del formulario pasan por el mismo armador de URL" do
    # El primario y el secundario preguntan lo mismo al mismo endpoint. Escrito
    # dos veces, uno se excluye y el otro no — que es cómo se separaron antes.
    src = Rails.root.join("app/javascript/controllers/etiquetar_controller.js").read

    assert_equal 2, src.scan("this._urlDeConsulta(").size
    assert_no_match(/\$\{this\.checkUrlValue\}\?tracking=/, src,
                    "una de las dos volvió a armar la URL por su cuenta")
    assert_includes src[/_urlDeConsulta\(valor\)\s*\{.*?\n  \}/m], "excluir_paquete_id"
  end

  private

  def crear_split(tracking, total)
    Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), tracking: tracking,
               descripcion: "Varias cajas", estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: [ total, 2 ].max, por_caja: {}
    )
  end
end
