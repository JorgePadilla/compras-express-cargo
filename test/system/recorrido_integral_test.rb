require "application_system_test_case"

# El recorrido completo, con todo lo que se cambió hoy junto.
#
# Jorge: *"hacé un revisado integral desde pre-alerta hasta paquetes, etiquetas
# y WR, con todos los cambios que hicimos hoy — que todo tenga sentido y se
# refleje. Por ejemplo, si pongo 2 cajas, que salgan en las etiquetas"*.
#
# Lo que tiene que cerrar de punta a punta:
#
#   · pre-alerta del cliente → el paquete esperado
#   · /etiquetar con 2 cajas → 2 paquetes, mismo tracking, numeradas 1 y 2
#   · el prepago de Miami con su forma de pago (PR #300)
#   · los productos POR CAJA (PR-C7.19)
#   · la etiqueta: una por caja
#   · el Warehouse Receipt: una fila por caja, Units real, y el badge con Zelle
#
# Va como system test porque la mitad es JS. **CI no lo corre** —`rails test`
# excluye `test/system`—, así que esto es una red para cuando se pide a mano.
class RecorridoIntegralTest < ApplicationSystemTestCase
  setup do
    @cliente = clientes(:juan)
    ingresar(users(:digitador))
  end

  test "de la pre-alerta al Warehouse Receipt, con dos cajas y prepago" do
    tracking = "1Z999INTEGRAL#{SecureRandom.hex(3).upcase}"

    # ── 1 · El cliente pre-alerta el paquete ────────────────────────────
    pre_alerta = PreAlerta.create!(
      cliente: @cliente, tipo_envio: tipo_envios(:cer),
      estado: "pre_alerta", titulo: "Recorrido integral"
    )
    pre_alerta.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Zapatos")
    assert_equal 1, pre_alerta.reload.pre_alerta_paquetes.size

    # ── 2 · Miami lo etiqueta: dos cajas, pagado con Zelle ──────────────
    abrir_etiquetar
    find("#paquete_tracking").set(tracking)
    elegir_cliente

    caja(peso: "12.5", alto: "10", largo: "12", ancho: "8", productos: "3")
    find("[data-cajas-repetidor-target='agregarBtn']").click
    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 2/i

    caja(peso: "30", alto: "20", largo: "20", ancho: "20", productos: "5")

    # El total cuenta la caja que se está escribiendo — el bug de la suma.
    assert_selector "[data-calc-volumetrico-target='totalCajas']", text: "2"

    # Prepago con forma de pago: lo que faltaba de PR #300.
    find("input[name='paquete[prepagado_miami]'][value='1']").click
    find("input[name='paquete[prepagado_miami_metodo]'][value='zelle']").click

    antes = Paquete.count
    find("[data-action*='etiquetar#submitForm']", match: :first).click
    esperar { Paquete.count == antes + 2 }
    page.save_screenshot("tmp/screenshots/e2e_1_etiquetar.png")

    # La segunda caja se agregó sola, sin apretar Agregar.
    todos = Paquete.where(tracking: tracking).order(:id)
    puts "\n  DIAGNOSTICO: #{todos.size} paquetes con ese tracking"
    todos.each { |p| puts "    id=#{p.id} estado=#{p.estado} caja=#{p.numero_caja.inspect} peso=#{p.peso.inspect}" }
    puts "  pre_alerta_paquetes: #{PreAlertaPaquete.where(tracking: tracking).map { |pap| "paquete_id=#{pap.paquete_id.inspect}" }.join(", ")}"

    cajas = Paquete.where(tracking: tracking).where.not(estado: "pre_alerta_estado").order(:numero_caja)
    assert_equal 2, cajas.size, "la caja a medio llenar se perdió"
    assert_equal [ 1, 2 ], cajas.map(&:numero_caja)
    assert_equal [ 12.5, 30.0 ], cajas.map { |p| p.peso.to_f }
    assert_equal [ 3, 5 ], cajas.map(&:cantidad_productos), "los productos son de cada caja"
    assert_equal [ "zelle" ], cajas.map(&:prepagado_miami_metodo).uniq
    assert(cajas.all?(&:prepagado_miami?), "el pago es del envío, no de una caja")

    # Y la pantalla quedó limpia para el siguiente paquete.
    assert_no_selector ".caja-fila"
    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 1/i

    # ── 3 · La ficha del paquete ────────────────────────────────────────
    visit paquete_path(cajas.first)
    assert_text "Este paquete ya fue pagado en Miami"
    assert_text "Zelle"
    page.save_screenshot("tmp/screenshots/e2e_2_paquete.png")

    # ── 4 · Las etiquetas: una por caja ─────────────────────────────────
    visit "#{etiqueta_paquete_path(cajas.first)}?hermanas=1"
    assert_selector ".etq", count: 2, wait: 5
    page.save_screenshot("tmp/screenshots/e2e_3_etiquetas.png")

    # ── 5 · El Warehouse Receipt ────────────────────────────────────────
    visit warehouse_receipt_paquete_path(cajas.first)
    assert_text "PREPAGADO EN MIAMI"
    assert_text "ZELLE"
    # Una fila por caja, con sus productos propios en Units.
    assert_selector "table tbody tr", minimum: 2
    assert_text "12.50"
    assert_text "30.00"
    page.save_screenshot("tmp/screenshots/e2e_4_wr.png")
  end

  private

  def caja(peso:, alto:, largo:, ancho:, productos:)
    find("[data-caja-campo='peso']").set(peso)
    find("[data-caja-campo='alto']").set(alto)
    find("[data-caja-campo='largo']").set(largo)
    find("[data-caja-campo='ancho']").set(ancho)
    find("[data-caja-campo='cantidad_productos']").set(productos)
  end

  def elegir_cliente
    page.execute_script(
      "document.querySelector('[data-etiquetar-target=clienteId]').value = arguments[0]",
      @cliente.id
    )
  end

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end

  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8
  end

  def abrir_etiquetar
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      # La sesión arranca en CER **a propósito**: la pre-alerta de este test es
      # CER, y si la sesión fuera otra el sistema abriría el modal de conflicto
      # — que es justo lo que tiene que hacer, pero no es lo que se prueba acá.
      find("button[name='tipo_envio_id'][value='#{tipo_envios(:cer).id}']").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end
end
