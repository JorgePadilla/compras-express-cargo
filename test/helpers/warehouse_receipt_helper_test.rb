require "test_helper"

class WarehouseReceiptHelperTest < ActionView::TestCase
  include WarehouseReceiptHelper

  # ── wr_packages_for ──

  test "wr_packages_for paquete no dividido devuelve solo a self" do
    p = paquetes(:recibido)
    assert_equal [ p ], wr_packages_for(p)
  end

  test "wr_packages_for paquete dividido devuelve self + hermanos ordenados" do
    miami = sucursales(:miami)
    paquetes_split = Paquete.crear_split!(
      attrs: { tracking: "1Z999WRSPLIT", cliente: clientes(:juan), sucursal: miami },
      total_cajas: 3
    )
    primero = paquetes_split.first
    result = wr_packages_for(primero.reload)
    assert_equal 3, result.size
    assert_equal [ 1, 2, 3 ], result.map(&:numero_caja)
  end

  # ── wr_totals ──

  test "wr_totals suma pesos y calcula KG/m3" do
    miami = sucursales(:miami)
    p1 = Paquete.create!(tracking: "1Z999WRT1", cliente: clientes(:juan), sucursal: miami,
                         peso: 100.0, alto: 12.0, largo: 12.0, ancho: 12.0)
    p2 = Paquete.create!(tracking: "1Z999WRT2", cliente: clientes(:juan), sucursal: miami,
                         peso: 50.0, alto: 6.0, largo: 6.0, ancho: 6.0)

    totals = wr_totals([ p1, p2 ])

    assert_equal 2, totals[:pieces]
    assert_equal 150.0, totals[:weight_lb]
    assert_in_delta 68.04, totals[:weight_kg], 0.05  # 150 * 0.4535924
    assert_in_delta 1.125, totals[:volume_cuft], 0.01 # (1728+216) in³ → ft³
    assert totals[:volume_m3] > 0
    assert totals[:vol_weight_lb] > 0
  end

  test "wr_totals con paquetes sin peso/dimensiones devuelve 0" do
    miami = sucursales(:miami)
    p = Paquete.create!(tracking: "1Z999WREMPTY", cliente: clientes(:juan), sucursal: miami)
    totals = wr_totals([ p ])
    assert_equal 1, totals[:pieces]
    assert_equal 0.0, totals[:weight_lb]
  end

  # ── wr_user_initials ──

  # RP-59 · **El punto se fue, y es a propósito.**
  #
  # Este helper tenía su propia cuenta de las iniciales, distinta de
  # `User#iniciales_display` en dos cosas: ignoraba `users.iniciales` —la
  # columna que llena el admin— y devolvía `Y.G.` donde el resto del sistema
  # dice `YG`. Lo destapó el manifiesto impreso, que muestra «Expedido por» e
  # «Imprimió» juntos: la misma persona salía escrita de dos formas en el mismo
  # papel.
  #
  # Ahora delega. El formato que gana es el sin puntos, que es lo que el admin
  # teclea en el formulario de usuarios (*"Ej: YG, JP, YS"*) y por lo tanto lo
  # que espera ver impreso.
  test "wr_user_initials con nombre completo devuelve las dos iniciales" do
    user = User.new(nombre: "Yulien Gonzalez", email_address: "y@test.com")
    assert_equal "YG", wr_user_initials(user)
  end

  test "wr_user_initials con un solo nombre devuelve una inicial" do
    user = User.new(nombre: "Madonna", email_address: "m@test.com")
    assert_equal "M", wr_user_initials(user)
  end

  test "wr_user_initials con nil devuelve guion" do
    assert_equal "—", wr_user_initials(nil)
  end

  test "wr_user_initials cae a email cuando no hay nombre" do
    user = User.new(nombre: "", email_address: "jorge@test.com")
    assert_equal "J", wr_user_initials(user)
  end

  # Lo que el helper ignoraba y ahora respeta: el alias que define el admin.
  # Yusef lo pidió *"porque hay nombres repetidos como Juan"* (`PR-D1.b`), y el
  # WR —el papel donde importa saber quién lo hizo— lo estaba tirando a la
  # basura.
  test "wr_user_initials respeta las iniciales que carga el admin" do
    user = User.new(nombre: "Juan Perez", iniciales: "JP2", email_address: "j2@test.com")
    assert_equal "JP2", wr_user_initials(user)
  end

  # ── wr_terms ──

  test "wr_terms devuelve español por default" do
    assert_match(/abandonada/i, wr_terms)
  end

  test "wr_terms con :en devuelve inglés" do
    text = wr_terms(language: :en)
    assert_match(/abandoned/i, text)
    assert_no_match(/abandonada/i, text)
  end

  # ── issuing company config ──

  test "wr_issuing_company carga config del initializer" do
    company = wr_issuing_company
    assert_equal "COMPRAS EXPRESS LOGISTICS LLC", company[:name]
    assert_equal "Miami", company[:city]
  end

  test "wr_terms_version está configurado" do
    assert_match(/\A\d{4}-\d{2}\z/, wr_terms_version)
  end
end
