require "test_helper"

# C18-06: la explicación al cliente se compone en `notas_al_cliente` al marcar
# «enviado según política», una sola vez, sin pisar lo que ya había.
class PaqueteEnviadoPorPoliticaTest < ActiveSupport::TestCase
  setup do
    @paquete = paquetes(:recibido)
    @sin_prealerta = motivos_envio_politica(:sin_prealerta)
    @etiqueta = motivos_envio_politica(:etiqueta_incompleta)
  end

  test "al marcarla, los textos de los motivos y el detalle van a notas_al_cliente" do
    @paquete.update!(enviado_por_politica: true, motivo_envio_politica_ids: [ @sin_prealerta.id, @etiqueta.id ],
                     notas_envio_politica: "Solo se leía «Juan».")

    nota = @paquete.reload.notas_al_cliente
    assert_includes nota, @sin_prealerta.texto_al_cliente
    assert_includes nota, @etiqueta.texto_al_cliente
    assert_includes nota, "Solo se leía «Juan»."
  end

  test "no pisa lo que ya había, y re-guardar no duplica" do
    @paquete.update!(notas_al_cliente: "Ya tenía esta nota.")

    @paquete.update!(enviado_por_politica: true, motivo_envio_politica_ids: [ @sin_prealerta.id ])
    @paquete.update!(descripcion: "otra cosa")
    @paquete.update!(peso: 9)

    nota = @paquete.reload.notas_al_cliente
    assert nota.start_with?("Ya tenía esta nota.")
    assert_equal 1, nota.scan(@sin_prealerta.texto_al_cliente).size, "se apendeó más de una vez"
  end

  test "un paquete nuevo tambien la compone" do
    p = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), tracking: "1ZPOLITICA000001",
                        descripcion: "Sin identificar", estado: "recibido_miami", user: users(:digitador),
                        enviado_por_politica: true, motivo_envio_politica_ids: [ @sin_prealerta.id ])

    assert_includes p.reload.notas_al_cliente, @sin_prealerta.texto_al_cliente
    assert_equal [ @sin_prealerta ], p.motivos_envio_politica.to_a
  end

  test "desmarcarla se lleva los motivos y el detalle, no la nota ya compuesta" do
    @paquete.update!(enviado_por_politica: true, motivo_envio_politica_ids: [ @sin_prealerta.id ],
                     notas_envio_politica: "detalle")

    @paquete.update!(enviado_por_politica: false)

    @paquete.reload
    assert_empty @paquete.motivos_envio_politica
    assert_nil @paquete.notas_envio_politica
    assert_includes @paquete.notas_al_cliente, @sin_prealerta.texto_al_cliente, "lo que ya se le dijo al cliente no se borra"
  end

  test "sin motivos ni detalle no compone nada" do
    @paquete.update!(enviado_por_politica: true)

    assert_nil @paquete.reload.notas_al_cliente
  end
end
