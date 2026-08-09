require "test_helper"

# PR-C6.20: el interruptor del cobro en medias libras.
#
# Yusef, contestando el PDF el 2026-08-09:
#
#   ☒ "Préndanlo ya."
#   ☒ "También en las tarifas por categoría: Clientes Amigos, Shein, Personal
#      CEC y las demás." — y al lado escribió: "Todo".
#
# Por ese "todo" no hay selector de alcance: entra la fila de lista y todas las
# de categoría, cliente, proveedor y sucursal. El selector por fila ya existía
# en el form; esto es la versión masiva, porque editar 58 filas a mano es donde
# se olvida una y una categoría termina facturando distinto.
#
# **Se mergea inerte**: el clic lo da Yusef (o Jorge en su nombre), con el
# informe de impacto en la mano. Y va DESPUÉS de PR-C6.18 — activar es
# exactamente lo que despierta el bug de frontera.
class ServiciosRedondeoTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @cem = tipo_envios(:cem)
    Tarifa.destroy_all
    @lista     = tarifa(@cer, desde: 0)
    @categoria = tarifa(@cer, desde: 0, categoria_precio: categoria_precios(:vip))
    @sucursal  = tarifa(@cer, desde: 50.5, sucursal: sucursales(:humuya_tgu))
    @otro      = tarifa(@cem, desde: 0)
  end

  test "activa todas las filas del servicio" do
    patch redondeo_servicio_url(@cer), params: { activar: "1" }

    assert_equal [ 0.5, 0.5, 0.5 ],
                 [ @lista, @categoria, @sucursal ].map { |t| t.reload.incremento_libras.to_f }
  end

  test "el 'todo' incluye las de categoria, no solo la de lista" do
    # Es la respuesta literal de Yusef a la pregunta 4. Si esto falla, un
    # Cliente Amigo factura con una regla y el público con otra.
    patch redondeo_servicio_url(@cer), params: { activar: "1" }

    assert_equal 0.5, @categoria.reload.incremento_libras.to_f
  end

  test "no toca las de otro servicio" do
    patch redondeo_servicio_url(@cer), params: { activar: "1" }

    assert_nil @otro.reload.incremento_libras,
               "activar CER movió las tarifas de CEM"
  end

  test "se puede volver atras sin deploy" do
    patch redondeo_servicio_url(@cer), params: { activar: "1" }
    patch redondeo_servicio_url(@cer), params: { activar: "0" }

    assert_nil @lista.reload.incremento_libras
    assert_nil @categoria.reload.incremento_libras
  end

  test "cada fila deja su version en el audit log" do
    # Es plata: tiene que poder rastrearse fila por fila. De ahí que sea
    # `find_each` + `save!` y no un `update_all`.
    assert_difference -> { PaperTrail::Version.where(item_type: "Tarifa").count }, 3 do
      patch redondeo_servicio_url(@cer), params: { activar: "1" }
    end
  end

  test "no versiona las que ya estaban como se pidio" do
    @lista.update!(incremento_libras: 0.5)

    assert_difference -> { PaperTrail::Version.where(item_type: "Tarifa").count }, 2 do
      patch redondeo_servicio_url(@cer), params: { activar: "1" }
    end
  end

  test "el listado dice como esta cada servicio" do
    patch redondeo_servicio_url(@cer), params: { activar: "1" }

    get servicios_url

    assert_match(/data-marca="estado-redondeo-cer"[^>]*>\s*medias libras/, response.body)
    assert_match(/data-marca="estado-redondeo-cem"[^>]*>\s*peso exacto/, response.body)
  end

  test "avisa cuando un servicio quedo a medias" do
    # El caso que este botón viene a evitar: alguien editó una fila a mano y
    # las demás quedaron atrás. Sin este aviso no se nota hasta la factura.
    @lista.update!(incremento_libras: 0.5)

    get servicios_url

    assert_match(/data-marca="estado-redondeo-cer"[^>]*>\s*medias libras a medias/, response.body)
  end

  test "un no-admin no puede prenderlo" do
    delete session_url
    post session_url, params: { email_address: users(:cajero).email_address, password: "password123" }

    patch redondeo_servicio_url(@cer), params: { activar: "1" }

    assert_redirected_to root_path
    assert_nil @lista.reload.incremento_libras
  end

  private

  def tarifa(tipo, desde:, **extra)
    Tarifa.create!({
      tipo_envio: tipo, desde_libras: desde, precio_libra: 4.50,
      moneda: "USD", activo: true, aplica_minimo: false
    }.merge(extra))
  end
end
