require "test_helper"

# PR-C6.9: no se puede guardar un paquete bajo el tipo de envío equivocado.
#
# **La pata que el doc no había visto.** `create_single` hace
# `@paquete.tipo_envio_id = @tipo_envio_sesion.id` **incondicional**, así que un
# paquete con pre-alerta CKM escaneado en una sesión CER se guardaba como CER
# **en silencio**. El modal del front es la mitad visible; el rechazo del
# servidor es la mitad que cobra bien.
#
# Yusef lo consultó con Julián (Miami) por videollamada en plena reunión:
#
#   > "No te va a permitir grabarlo. No vas a poder hacerlo... el chavo no hizo
#   >  nada, no pudo hacer nada."
#
# Y las dos salidas que acordaron: finalizar la sesión para abrir la del tipo
# correcto, o seguir en la misma dejando el paquete de lado. En ninguna se graba.
class EtiquetarSesionBloqueoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @miami = sucursales(:miami)
    @cer = tipo_envios(:cer)
    # CEM y no CKM: la pre-alerta fixture trae varios paquetes, y CKM tiene
    # `max_paquetes_por_accion: 1`. El tipo concreto da igual para lo que se
    # prueba — lo que importa es que sea distinto al de la sesión.
    @otro = tipo_envios(:cem)

    # Una pre-alerta de otro tipo, con un tracking sin vincular.
    @pa = pre_alertas(:activa)
    @pa.update!(tipo_envio: @otro)
    @pap = pre_alerta_paquetes(:pap_sin_vincular)
  end

  test "un paquete con pre-alerta de otro tipo NO se graba" do
    iniciar_sesion_en(@cer)

    assert_no_difference -> { Paquete.count } do
      post etiquetar_url, params: { paquete: attrs(tracking: @pap.tracking) }
    end

    assert_response :unprocessable_entity
    assert_match(/otro|pre-alerta/i, flash[:alert].to_s)
  end

  test "el mensaje dice de que tipo es y en cual esta trabajando" do
    iniciar_sesion_en(@cer)

    post etiquetar_url, params: { paquete: attrs(tracking: @pap.tracking) }

    assert_match @otro.nombre, flash[:alert].to_s
    assert_match @cer.nombre, flash[:alert].to_s
  end

  test "en la sesion correcta si se graba" do
    iniciar_sesion_en(@otro)

    assert_difference -> { Paquete.count }, 1 do
      post etiquetar_url, params: { paquete: attrs(tracking: @pap.tracking) }
    end

    assert_equal @otro, Paquete.order(:id).last.tipo_envio
  end

  test "sin pre-alerta manda la sesion, sin preguntar" do
    iniciar_sesion_en(@cer)

    assert_difference -> { Paquete.count }, 1 do
      post etiquetar_url, params: { paquete: attrs(tracking: "SINPA#{SecureRandom.hex(4)}") }
    end

    assert_equal @cer, Paquete.order(:id).last.tipo_envio
  end

  test "el cambio de servicio es la excepcion explicita" do
    # Ahí el operario declaró que el paquete sale de la sesión, así que no hay
    # conflicto que reportar — es justamente lo que vino a hacer.
    iniciar_sesion_en(@cer)

    assert_difference -> { Paquete.count }, 1 do
      post etiquetar_url, params: {
        paquete: attrs(tracking: @pap.tracking).merge(
          solicito_cambio_servicio: "1", tipo_envio_destino_id: @otro.id
        )
      }
    end

    assert_equal @otro, Paquete.order(:id).last.tipo_envio
  end

  test "un split tampoco se graba bajo el tipo equivocado" do
    iniciar_sesion_en(@cer)

    assert_no_difference -> { Paquete.count } do
      post etiquetar_url, params: {
        paquete: attrs(tracking: @pap.tracking).merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 5 }, "3" => { peso: 5 } })
      }
    end

    assert_response :unprocessable_entity
  end

  test "check_tracking devuelve el tipo de la pre-alerta para el aviso" do
    get check_tracking_paquetes_url, params: { tracking: @pap.tracking },
        headers: { "Accept" => "application/json" }

    data = JSON.parse(response.body)
    assert data["pre_alerta_match"]
    assert_equal @otro.id, data["pre_alerta_tipo_envio_id"]
    assert_equal @otro.nombre, data["pre_alerta_tipo_envio"]
  end

  # A7-17. Yusef escaneó un paquete con pre-alerta CER en una sesión EXPRESS,
  # le salió el banner rojo, y siguió llenando el formulario:
  #
  #   > "Ya me tira esto, pero esto yo me refería que me lo tirara **como
  #   >  modal**. Mira lo que pasa ahora: **yo lo puedo recibir**."
  #   > "**Te tiene que bloquear la pantalla**, porque tenés que usar una de las
  #   >  opciones obligadas de ahí."
  #
  # El aviso vive en el HTML aunque arranque oculto —el JS solo le saca el
  # `hidden`—, así que se puede probar su forma sin navegador.
  test "el aviso de conflicto tapa la pantalla, no es un banner" do
    iniciar_sesion_en(@cer)
    get etiquetar_url

    aviso = css_select("[data-etiquetar-target='conflictoSesionModal']").first
    assert aviso, "no existe el modal de conflicto de sesión"

    clases = aviso["class"].to_s
    assert_includes clases, "fixed", "el aviso tiene que tapar la pantalla, no fluir con el formulario"
    assert_includes clases, "inset-0"
    assert_includes clases, "hidden", "arranca oculto: lo abre el JS al detectar el conflicto"
    assert_equal "alertdialog", aviso["role"]
    assert_equal "true", aviso["aria-modal"]
  end

  test "el modal de conflicto obliga: las dos salidas y ninguna escapatoria" do
    iniciar_sesion_en(@cer)
    get etiquetar_url

    modal = css_select("[data-etiquetar-target='conflictoSesionModal']").first
    texto = modal.text

    assert_match(/finalizar la sesión/i, texto)
    assert_match(/dejarlo de lado/i, texto)

    # Sin Cancelar y sin cerrar: las dos opciones SON la salida. Si alguien
    # agrega una tercera vía de escape, esto falla y hay que volver al audio.
    refute_match(/cancelar|cerrar/i, texto,
                 "el modal no lleva escapatoria: Yusef pidió opciones obligadas")
  end

  private

  def iniciar_sesion_en(tipo)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo.id, sucursal_recepcion_id: @miami.id }
  end

  def attrs(tracking:)
    {
      tracking: tracking,
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
