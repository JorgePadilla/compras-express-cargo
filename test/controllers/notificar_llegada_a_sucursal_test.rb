require "test_helper"

# `A7-08` · Avisarle a los clientes que su carga llegó a la sucursal.
#
#   > **Yusef:** "Con el manifiesto notifique, pero darle una ventana de media
#   >  hora, por ejemplo, o una hora."
#
# **Sin ventana**, y por una razón que no es de diseño: la cola de trabajos no
# está conectada —el adaptador efectivo es `AsyncAdapter`, no hay tablas de
# `solid_queue`— y un job a 30-60 minutos se pierde en el primer reinicio. Jorge
# eligió notificar **al cerrar la recepción**, que es cuando el conteo que la
# ventana venía a esperar ya terminó.
class NotificarLlegadaASucursalTest < ActionDispatch::IntegrationTest
  setup do
    @manifiesto = Manifiesto.create!(
      tipo: "interno", estado: "enviado",
      sucursal_origen: sucursales(:zeron_sps),
      sucursal_entrega: sucursales(:humuya_tgu),
      tipo_envios: [ tipo_envios(:cer) ]
    )
    ingresar(users(:supervisor_prefactura))
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def paquete_de(cliente)
    Paquete.create!(
      tracking: "1Z#{SecureRandom.hex(5).upcase}",
      cliente: cliente, tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:humuya_tgu),
      sucursal_destino: sucursales(:humuya_tgu),
      estado: "enviado_sucursal", descripcion: "Perfumes", peso: 5,
      user: users(:digitador), manifiesto: @manifiesto
    )
  end

  def escanear(paquete)
    post escanear_recepcion_carga_url(@manifiesto), params: { codigo: paquete.tracking }
  end

  def cerrar(**params)
    patch finalizar_recepcion_carga_url(@manifiesto, **params)
  end

  # ── A quién se le avisa ─────────────────────────────────────────────────

  test "al cerrar se le avisa a cada cliente cuya carga llegó" do
    escanear(paquete_de(clientes(:juan)))
    escanear(paquete_de(clientes(:maria)))

    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      perform_enqueued_jobs { cerrar }
    end

    destinatarios = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
    assert_includes destinatarios, clientes(:juan).email
    assert_includes destinatarios, clientes(:maria).email
  end

  # Un correo **por cliente**, no por paquete: quien tiene tres cajas en el mismo
  # camión no puede recibir tres correos seguidos.
  test "un cliente con varios paquetes recibe un solo correo que los nombra" do
    a = paquete_de(clientes(:juan))
    b = paquete_de(clientes(:juan))
    escanear(a)
    escanear(b)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs { cerrar }
    end

    correo = ActionMailer::Base.deliveries.last
    assert_match(/2 paquetes disponibles/, correo.subject)
    assert_match(/#{a.tracking}/, correo.body.encoded)
    assert_match(/#{b.tracking}/, correo.body.encoded)
  end

  # `A7-13` · El nombre de la sucursal va en el asunto, y es el punto del aviso.
  # La queja que lo motivó: *"han ido a recogerlo a Tegucigalpa y no está ahí"*.
  test "el asunto dice en qué sucursal está" do
    escanear(paquete_de(clientes(:juan)))
    perform_enqueued_jobs { cerrar }

    assert_match(/#{sucursales(:humuya_tgu).nombre}/, ActionMailer::Base.deliveries.last.subject)
  end

  # ── A quién NO ──────────────────────────────────────────────────────────

  test "al que no llegó no se le avisa" do
    llego = paquete_de(clientes(:juan))
    paquete_de(clientes(:maria))  # se queda en camino
    escanear(llego)

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs { cerrar(con_faltantes: true) }
    end

    destinatarios = ActionMailer::Base.deliveries.last.to
    assert_includes destinatarios, clientes(:juan).email
    assert_not_includes destinatarios, clientes(:maria).email,
                        "se le avisó de un paquete que no llegó: iría a buscarlo en vano"
  end

  test "cerrar dos veces no manda el correo de nuevo" do
    escanear(paquete_de(clientes(:juan)))
    perform_enqueued_jobs { cerrar }

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      perform_enqueued_jobs { cerrar }
    end
  end

  test "un cliente sin correo no traba el cierre de los demás" do
    sin_correo = clientes(:maria)
    sin_correo.update_columns(email: nil)
    escanear(paquete_de(clientes(:juan)))
    escanear(paquete_de(sin_correo))

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs { cerrar }
    end

    assert_equal "recibido", @manifiesto.reload.estado
  end

  # ── El oficial no cambia ────────────────────────────────────────────────

  test "cerrar un manifiesto oficial no manda este aviso" do
    oficial = Manifiesto.create!(sucursal_origen: sucursales(:miami), estado: "enviado",
                                 tipo_envios: [ tipo_envios(:cer) ])

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      perform_enqueued_jobs { patch finalizar_recepcion_carga_url(oficial) }
    end
  end

  # ── A7-08 · La ventana, ahora que hay cola (2026-09-06) ──────────────────
  #
  # Yusef: *"con el manifiesto notifique, pero darle una ventana de media hora,
  # por ejemplo, o una hora"*. Del 2026-09-01 al 06 no la hubo porque no había
  # cola. Dos que avisan —la ventana y el cierre— y ningún correo repetido.

  test "el primer paquete escaneado programa el aviso a la ventana" do
    freeze_time do
      assert_enqueued_with(job: NotificarLlegadaASucursalJob, args: [ @manifiesto ], at: 30.minutes.from_now) do
        escanear(paquete_de(clientes(:juan)))
      end
    end

    assert_not_nil @manifiesto.reload.aviso_llegada_programado_at
  end

  test "el segundo paquete no programa otro aviso" do
    escanear(paquete_de(clientes(:juan)))

    assert_no_enqueued_jobs(only: NotificarLlegadaASucursalJob) do
      escanear(paquete_de(clientes(:maria)))
    end
  end

  # RP-32 (¿media hora o una hora?) sigue abierta: va en 30 y se cambia sin deploy.
  test "la ventana se cambia por configuración, sin deploy" do
    Configuracion.set("ventana_aviso_llegada_min", "60", tipo: "integer", categoria: "general")

    freeze_time do
      assert_enqueued_with(job: NotificarLlegadaASucursalJob, at: 60.minutes.from_now) do
        escanear(paquete_de(clientes(:juan)))
      end
    end
  end

  test "la ventana avisa lo escaneado hasta ahí, y cerrar después solo a los que faltaban" do
    escanear(paquete_de(clientes(:juan)))

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      disparar_ventana # Juan recibe su correo
    end
    assert_equal [ clientes(:juan).email ], ActionMailer::Base.deliveries.last.to

    escanear(paquete_de(clientes(:maria)))
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs { cerrar }
    end
    assert_equal [ clientes(:maria).email ], ActionMailer::Base.deliveries.last.to, "a Juan no se le repite"
  end

  test "cerrar antes de la ventana avisa a todos, y la ventana después no repite a nadie" do
    escanear(paquete_de(clientes(:juan)))
    escanear(paquete_de(clientes(:maria)))

    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      perform_enqueued_jobs { cerrar }
    end
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      disparar_ventana # sobre paquetes ya avisados: nadie
    end
  end

  # El job de la ventana encola el correo **adentro**, y `perform_enqueued_jobs`
  # sin bloque solo corre lo que ya estaba encolado al llamarlo: hay que
  # vaciar dos veces, el job y después el correo.
  def disparar_ventana
    perform_enqueued_jobs(only: NotificarLlegadaASucursalJob)
    perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob)
  end
end
