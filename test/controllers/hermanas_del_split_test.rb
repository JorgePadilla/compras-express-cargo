require "test_helper"

# Quiénes son "las hermanas" de una caja, escrito una sola vez.
#
# La regla vivía en dos lugares: `Paquete#paquetes_hermanos` y una copia a mano
# adentro de `PaquetesController#etiqueta`. El Warehouse Receipt sí pasaba por el
# modelo. Así que arreglar uno no arreglaba el otro — el mismo bug recurrente de
# este repo, esta vez adentro de un solo archivo y su controller.
#
# Lo que se coló por ahí: un paquete en `pre_alerta_estado` con el mismo tracking
# —lo que el cliente anunció y todavía no llegó— salía **como una etiqueta más**,
# con `—` donde va el número de recepción, y contaba como pieza en el WR.
#
# `PR-C7.20` hace que /etiquetar ya no deje esperados huérfanos. Esto es la red de
# abajo: un esperado puede aparecer igual —el cliente pre-alerta un tracking
# **después** de que la carga llegó— y una etiqueta de más se pega en una caja
# que no existe.
class HermanasDelSplitTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    @cajas = Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
               tracking: "1Z999HERMANAS001", descripcion: "Dos cajas",
               estado: "recibido_miami", user: users(:admin),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 2, por_caja: { 1 => { peso: 12.5 }, 2 => { peso: 30 } }
    )
  end

  test "un esperado del mismo tracking no es una hermana" do
    esperado_colgado

    assert_equal 1, @cajas.first.paquetes_hermanos.count
    assert_equal [ @cajas.second.id ], @cajas.first.paquetes_hermanos.ids
  end

  test "hermanas=1 saca una etiqueta por caja, no una por registro" do
    esperado_colgado

    get etiqueta_paquete_url(@cajas.first, hermanas: 1)

    assert_response :success
    assert_select ".etq", 2
  end

  test "el Warehouse Receipt cuenta las cajas, no los registros" do
    esperado_colgado

    get warehouse_receipt_paquete_url(@cajas.first)

    assert_response :success
    assert_select "table.wr-pkg tbody tr", 2
  end

  test "sin nada colgado sigue sacando las dos" do
    get etiqueta_paquete_url(@cajas.first, hermanas: 1)

    assert_response :success
    assert_select ".etq", 2
  end

  test "la regla de las hermanas se escribe en un solo lugar" do
    # Es lo que impide que se vuelvan a separar. Si el controller vuelve a armar
    # su propia consulta por tracking, las etiquetas y el WR pueden discrepar
    # otra vez sin que nadie se entere: los dos síntomas se ven en papel
    # distinto.
    src = Rails.root.join("app/controllers/paquetes_controller.rb").read
    accion = src[/def etiqueta\b.*?\n  end/m]
    assert accion, "no se encontró la acción `etiqueta`"

    assert_includes accion, "paquetes_hermanos"
    assert_no_match(/Paquete\.where\(tracking:/, accion,
                    "el controller volvió a resolver las hermanas por su cuenta")
  end

  private

  # El paquete que una pre-alerta deja esperando, con el mismo tracking que las
  # cajas que ya llegaron.
  def esperado_colgado
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Anunciada tarde", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: "1Z999HERMANAS001", descripcion: "Lo mismo")
  end
end
