require "test_helper"

# PR-C6.14: el tercero como texto libre, que NO toca la base de clientes.
#
# Yusef, 2026-08-08, sobre quién digita en Miami:
#
#   "Solo se guarda en esa guía... queda guardado en ese warehouse receipt,
#    pero **no queda grabado en ninguna base de datos de clientes**."
#
# Las dos razones que dio, y las dos son de autoridad, no de UI:
#
#   1. "El que está digitando ahí no tiene ni voz ni voto para guardar."
#   2. "Ellos se pueden equivocar y pueden hacer este relajo."
#
# El diagnóstico del doc decía "verificar que no esté creando clientes". La
# verificación pasa —`tercero_id` solo se asigna eligiendo un `Cliente` que ya
# existe— pero **el texto libre que él pidió no existía**, así que a un tercero
# fuera de la cartera no se le podía poner el nombre en la etiqueta. Y ese es
# el caso normal: "nosotros no tenemos la base de datos completa de los
# clientes terceros".
class TerceroTextoLibreTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "un tercero escrito a mano NO crea un cliente" do
    # La regla de autoridad de Yusef, medida donde se puede medir.
    assert_no_difference -> { Cliente.count } do
      post etiquetar_url, params: {
        paquete: attrs.merge(tercero_nombre: "Ferretería El Martillo")
      }
    end

    assert_equal "Ferretería El Martillo", Paquete.order(:id).last.tercero_nombre
  end

  test "el nombre queda solo en ese paquete" do
    post etiquetar_url, params: { paquete: attrs.merge(tercero_nombre: "Juan del Pueblo") }
    p1 = Paquete.order(:id).last

    post etiquetar_url, params: { paquete: attrs }
    p2 = Paquete.order(:id).last

    assert_equal "Juan del Pueblo", p1.tercero_nombre
    assert_nil p2.tercero_nombre, "el nombre se filtró a otro paquete"
  end

  test "el catalogo manda sobre el texto libre" do
    # Si alguien eligió un cliente de verdad, ese nombre es el bueno.
    p = Paquete.new(tercero: clientes(:maria), tercero_nombre: "escrito a mano")

    assert_equal clientes(:maria).nombre_completo, p.tercero_display
  end

  test "sin ninguno de los dos no hay tercero" do
    assert_nil Paquete.new.tercero_display
  end

  test "la etiqueta muestra el tercero escrito a mano" do
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(tercero: nil, tercero_nombre: "Ferretería El Martillo")

    get etiqueta_paquete_url(paquete)

    assert_response :success
    assert_match(/FERRETERÍA EL MARTILLO/i, response.body)
  end

  test "el detalle lo muestra sin hacerlo pasar por cliente" do
    # Sin link ni código: no es un Cliente y no debe parecerlo.
    paquete = paquetes(:recibido)
    paquete.update!(tercero: nil, tercero_nombre: "Ferretería El Martillo")

    get paquete_url(paquete)

    assert_match "Ferretería El Martillo", response.body
    assert_match(/solo en este paquete/, response.body)
  end

  test "se puede corregir sin tocar ningun cliente" do
    post etiquetar_url, params: { paquete: attrs.merge(tercero_nombre: "mal escrito") }
    paquete = Paquete.order(:id).last

    assert_no_difference -> { Cliente.count } do
      patch actualizar_etiquetar_url(paquete), params: { paquete: { tercero_nombre: "bien escrito" } }
    end

    assert_equal "bien escrito", paquete.reload.tercero_nombre
  end

  private

  def attrs
    {
      tracking: "TER#{SecureRandom.hex(4)}",
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
