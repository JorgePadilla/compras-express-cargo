require "application_system_test_case"

# C30-12 · Yusef, 2026-10-09: *"¿ahora puedo de alguna manera ver los volúmenes
# de los paquetes que hemos medido?… como un buscador, por cliente o
# warehouse"*. Se llega desde el menú, y la pistola sirve en el buscador: el
# escaneo termina en Enter y Enter envía.
class VolumenesMedidosSystemTest < ApplicationSystemTestCase
  test "desde el menú, y buscando con la pistola por el warehouse de una caja" do
    juan = medido("1ZVOLSIS00000001", "SPS2610000911", clientes(:juan))
    otro = medido("1ZVOLSIS00000002", "SPS2610000912", Cliente.where.not(id: clientes(:juan).id).first)

    ingresar(users(:medidor))
    visit medicion_index_path
    # La barra plegada se abre al pasar el mouse, y en medio de la animación
    # Selenium mide el link en un lado y hace click en otro (le pegaba a
    # «Medición»). Que la opción esté en el menú lo cuida
    # `pantallas_en_el_menu_test`; acá importa que el link lleve a la pantalla.
    find("a[title='Volúmenes medidos']", visible: :all).execute_script("this.click()")

    assert_selector "h1", text: "Volúmenes medidos", wait: 10
    assert_selector "tr#bulto_#{juan.id}"
    assert_selector "tr#bulto_#{otro.id}"
    page.save_screenshot(ENV["CAPTURA"]) if ENV["CAPTURA"]

    find("input[name='q']").send_keys("SPS2610000912", :enter)

    assert_selector "tr#bulto_#{otro.id}"
    assert_no_selector "tr#bulto_#{juan.id}"
  end

  private

  def medido(tracking, wr, cliente)
    sesion = SecureRandom.uuid
    Paquete.create!(tracking: tracking, numero_recepcion: wr, cliente: cliente, tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Ropa", peso: 2,
                    medicion_sesion: sesion, medido_at: Time.current)
    Bulto.create!(cliente: cliente, user: users(:medidor), sesion: sesion, medido_at: Time.current,
                  peso: 4.5, alto: 14, largo: 12, ancho: 10)
  end
end
