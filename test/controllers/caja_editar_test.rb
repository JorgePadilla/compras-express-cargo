require "test_helper"

# C28-05 · Corregir una caja del manifiesto ya armada.
#
# Yusef, 2026-10-03: *"aquí es donde necesito que le des la opción de
# editarla… también para corregirla"* · *"marqué quiero una EH y al final… la
# hice en una E… le corté un pedazo"*. Y por qué no alcanza con borrar y volver
# a armar: *"ya los he visto confundirse"*.
class CajaEditarTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
    # Se arma sin peso: *"la voy a agregar sin peso porque voy a empacar…
    # después le voy a agregar el peso"*.
    @caja = @manifiesto.cajas.create!(alto: 23, largo: 23, ancho: 36)
  end

  test "guardar cambios corrige medidas y peso, y recalcula el manifiesto" do
    patch manifiesto_caja_path(@manifiesto, @caja),
          params: { caja_manifiesto: { alto: 20, largo: 23, ancho: 36, peso: 131 } }

    assert_redirected_to manifiesto_path(@manifiesto)
    @caja.reload
    assert_equal 20, @caja.alto.to_i
    assert_equal 131, @caja.peso.to_i
    assert_equal 131, @manifiesto.reload.peso_total.to_i
    assert_equal "A", @caja.letra, "corregir no le cambia la letra"
  end

  # El mismo redirect que «Agregar e imprimir»: sin popup, que Chrome bloquea.
  test "guardar e imprimir reimprime la 4×6 con los números nuevos" do
    patch manifiesto_caja_path(@manifiesto, @caja),
          params: { print: "true", caja_manifiesto: { peso: 131 } }

    assert_redirected_to etiqueta_manifiesto_caja_path(@manifiesto, @caja, print: true, volver: 1)
  end

  test "cada fila lleva su lápiz con los datos de la caja" do
    get manifiesto_path(@manifiesto)

    assert_select "button[data-action='caja-manifiesto#editar'][data-letra='A'][data-url=?]",
                  manifiesto_caja_path(@manifiesto, @caja)
    assert_select "[data-caja-manifiesto-target='editando'][hidden]"
  end

  test "al borrar, el aviso dice cuál va a ser la próxima letra" do
    @manifiesto.cajas.create!(peso: 1)  # B
    b = @manifiesto.cajas.find_by!(letra: "B")

    delete manifiesto_caja_path(@manifiesto, b)

    assert_match(/despegala: la próxima caja va a ser la B/, flash[:notice])
  end
end
