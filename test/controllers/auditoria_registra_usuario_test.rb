require "test_helper"

# PR-C6.30: el audit log registraba **qué** cambió pero nunca **quién**.
#
# `ApplicationController` tiene desde PR-D1.a:
#
#     before_action -> { set_paper_trail_whodunnit if respond_to?(:set_paper_trail_whodunnit) }
#
# `set_paper_trail_whodunnit` viene **protected** de paper_trail, y
# `respond_to?` sin el flag de `include_all` devuelve false para protegidos y
# privados. La guarda "defensiva" daba false **siempre**: el hook nunca corrió
# y todas las versiones de los 41 modelos quedaron con `whodunnit` nil.
#
# Nadie lo reportó porque en pantalla se lee "Sistema", que es exactamente lo
# que se muestra cuando un cambio lo hace un job. Salió escribiendo el test de
# auditoría de la pantalla de tasa de cambio (PR-C6.29).
#
# Importa porque la auditoría es lo que respalda los cambios de plata: quién
# tocó un precio, quién apagó un cobro, quién movió la tasa.
class AuditoriaRegistraUsuarioTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "un cambio hecho desde el sistema guarda el usuario" do
    paquete = paquetes(:recibido)

    patch paquete_url(paquete), params: { paquete: { descripcion: "contenido corregido" } }

    version = PaperTrail::Version.where(item_type: "Paquete", item_id: paquete.id).order(:created_at).last
    assert_equal @user.id.to_s, version.whodunnit.to_s,
                 "la version quedo sin usuario: el audit log no sirve para rastrear nada"
  end

  test "tambien en los modelos de plata" do
    # No alcanza con que funcione en Paquete: el valor de la auditoria esta en
    # los cambios que mueven dinero. El ISV de la empresa entra en cada
    # factura, asi que es el mismo tipo de dato que la tasa de cambio.
    patch empresa_url, params: { empresa: { isv_rate: 0.16 } }

    version = PaperTrail::Version.where(item_type: "Empresa").order(:created_at).last
    assert_equal @user.id.to_s, version.whodunnit.to_s
  end

  test "el detalle del paquete muestra el nombre, no un id suelto" do
    # Se busca DENTRO de la tabla de auditoria: el nombre del usuario sale en
    # media pagina (el menu, el saludo), asi que buscarlo en `response.body`
    # pasaba aunque el historial dijera "Sistema".
    paquete = paquetes(:recibido)
    patch paquete_url(paquete), params: { paquete: { descripcion: "otra cosa" } }

    get paquete_url(paquete)
    tabla = response.body[/data-tabla="auditoria".*?<\/table>/m].to_s

    assert_match @user.nombre, tabla
    assert_no_match(/Sistema/, tabla)
  end

  test "lo que de verdad hace un job sigue diciendo Sistema" do
    # El arreglo no puede inventar un usuario donde no lo hay.
    paquete = paquetes(:recibido)
    PaperTrail::Version.where(item_type: "Paquete", item_id: paquete.id).delete_all
    PaperTrail.request(whodunnit: nil) { paquete.update!(descripcion: "cambio de un job") }

    get paquete_url(paquete)
    tabla = response.body[/data-tabla="auditoria".*?<\/table>/m].to_s

    assert_match(/Sistema/, tabla)
  end

  test "un cambio sin sesion no atribuye nada" do
    delete session_url
    paquete = paquetes(:recibido)
    PaperTrail::Version.where(item_type: "Paquete", item_id: paquete.id).delete_all

    # Sin usuario logueado el request se rechaza, pero el punto es que el hook
    # no invente un whodunnit: `user_for_paper_trail` devuelve nil.
    patch paquete_url(paquete), params: { paquete: { descripcion: "anonimo" } }

    assert_nil PaperTrail::Version.where(item_type: "Paquete", item_id: paquete.id).last&.whodunnit
  end
end
