require "test_helper"

# C33-02 · La pre-alerta, con copia a SAC al crearla. Yusef, 2026-10-24:
# *"crear la prealerta, que te mande al cliente… y nosotros lo
# supervisamos… y una copia"*. Jorge, 2026-10-25: la copia va **solo** en el
# correo de creación, no en los que salen cuando el cliente mueve paquetes.
class CopiaASacDeLaPreAlertaTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  SAC = PreAlertaMailer::CORREO_DE_SAC

  setup do
    @cliente = clientes(:juan)
    @cliente.update!(password: "Cliente123!", acceso_habilitado: true, activo: true)
    ActionMailer::Base.deliveries.clear
  end

  test "el wizard del portal le manda la confirmacion al cliente con copia a SAC" do
    entrar_como_cliente
    post cuenta_pre_alertas_url, params: { wizard_step: 1, tipo_envio_id: tipo_envios(:cer).id }
    post cuenta_pre_alertas_url, params: { wizard_step: 2, consolidado: "0" }

    perform_enqueued_jobs do
      post cuenta_pre_alertas_url, params: { wizard_step: 3, titulo: "Televisor", proveedor: "Best Buy",
                                             tracking: "SACWIZ001", descripcion: "Televisor" }
    end

    correo = confirmaciones.sole
    assert_equal [ @cliente.email ], correo.to
    assert_equal [ SAC ], correo.cc
    assert PreAlerta.last.notificado?
  end

  test "la que crea el personal tambien le avisa al cliente, con la copia" do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    perform_enqueued_jobs do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: @cliente.id, tipo_envio_id: tipo_envios(:aereo).id, titulo: "Desde la oficina",
        consolidado: false, con_reempaque: false,
        pre_alerta_paquetes_attributes: { "0" => { tracking: "SACADMIN001", descripcion: "Zapatos" } }
      } }
    end

    correo = confirmaciones.sole
    assert_equal [ @cliente.email ], correo.to
    assert_equal [ SAC ], correo.cc
  end

  test "mover un paquete despues ya no le copia a SAC" do
    entrar_como_cliente
    origen = pre_alertas(:activa)
    destino = pre_alertas(:consolidada_destino)
    [ origen, destino ].each { |pa| pa.update_column(:notificado, true) }

    perform_enqueued_jobs do
      post mover_paquete_cuenta_pre_alerta_url(origen), params: {
        pre_alerta_paquete_id: pre_alerta_paquetes(:pap_sin_vincular).id, destino_id: destino.id
      }
    end

    assert confirmaciones.any?, "mover sigue avisándole al cliente"
    assert confirmaciones.all? { |c| c.cc.blank? }, "y SAC no recibe cada movimiento"
  end

  test "el primer correo de una pre-alerta que no se habia avisado lleva la copia, y el segundo no" do
    pa = pre_alertas(:activa)

    perform_enqueued_jobs do
      pa.enviar_confirmacion
      pa.enviar_confirmacion
    end

    assert_equal [ [ SAC ], nil ], confirmaciones.map(&:cc)
  end

  private

  def entrar_como_cliente
    post session_url, params: { email_address: @cliente.email, password: "Cliente123!" }
  end

  def confirmaciones
    ActionMailer::Base.deliveries.select { |c| c.subject.to_s.include?("confirmada") }
  end
end
