require "test_helper"

# C24-01 · La excepción de cobro, desde la pantalla.
#
# Lo que este archivo cuida por encima de todo es que **haya una sola puerta**:
# el peso a cobrar se mueve por `MarcarCobroExcepcion` con PIN, y por ningún
# otro lado. Es la misma regla que `PR-13.d` le puso al precio de una línea —
# *"si el admin puede editar suelto, el registro tiene un agujero y deja de
# servir como prueba"*.
class CobroExcepcionTest < ActionDispatch::IntegrationTest
  setup do
    @supervisor = users(:supervisor_prefactura)
    @supervisor.update!(pin: "1234")

    @paquete = paquetes(:recibido)
    @paquete.update!(peso: 400, alto: nil, largo: nil, ancho: nil,
                     tipo_envio: tipo_envios(:express),
                     pre_factura_id: nil, venta_id: nil)
    @paquete.update_columns(peso_volumetrico: 150, peso_cobrar: 400, cobro_excepcion: nil)

    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
  end

  test "con PIN correcto el paquete pasa a cobrar el volumétrico" do
    marcar

    assert_redirected_to paquete_path(@paquete)
    assert_equal "solo_volumetrico", @paquete.reload.cobro_excepcion
    assert_equal 150, @paquete.peso_cobrar.to_i
  end

  test "el aviso dice el peso nuevo, que es lo que el operario necesita ver" do
    marcar

    assert_match(/150/, flash[:notice])
  end

  test "con PIN equivocado no cambia nada y lo dice" do
    marcar(pin: "9999")

    assert_nil @paquete.reload.cobro_excepcion
    assert_match(/pin/i, flash[:alert])
  end

  test "un usuario sin rol autorizante no puede, aunque tenga PIN" do
    cajero = users(:cajero)
    cajero.update!(pin: "1234")

    marcar(supervisor: cajero)

    assert_nil @paquete.reload.cobro_excepcion
    assert_match(/no puede/i, flash[:alert])
  end

  test "sin motivo no pasa" do
    marcar(motivo: "")

    assert_nil @paquete.reload.cobro_excepcion
    assert_match(/motivo/i, flash[:alert])
  end

  # ── La única puerta ──────────────────────────────────────────────────────

  # Si esto falla, todo el control que pidió Yusef se puede saltar con un PATCH.
  test "no se puede escribir por el update normal del paquete" do
    patch paquete_path(@paquete), params: { paquete: { cobro_excepcion: "solo_volumetrico" } }

    assert_nil @paquete.reload.cobro_excepcion,
               "`cobro_excepcion` no puede estar en `paquete_params`: la única puerta es el PIN"
  end

  # ── Que se vea ───────────────────────────────────────────────────────────

  test "la ficha avisa que este paquete cobra por volumen, y quién lo autorizó" do
    marcar

    get paquete_path(@paquete)

    assert_match(/cobro por volumen/i, response.body)
    assert_match(/#{Regexp.escape(@supervisor.nombre)}/, response.body)
  end

  test "sin excepción la ficha no inventa ninguna insignia" do
    get paquete_path(@paquete)

    assert_no_match(/cobro por volumen/i, response.body)
  end

  private

  def marcar(supervisor: @supervisor, pin: "1234", motivo: "generadores",
             excepcion: "solo_volumetrico")
    post cobro_excepcion_paquete_path(@paquete),
         params: { cobro_excepcion: excepcion, supervisor_id: supervisor.id,
                   pin: pin, motivo: motivo }
  end
end
