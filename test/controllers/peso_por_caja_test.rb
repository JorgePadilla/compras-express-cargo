require "test_helper"

# PR-C6.17: cada caja de un split lleva su propio peso y sus propias medidas.
#
# Jorge probándolo: "cuando son 2 productos, ¿cómo le pongo los valores a la
# otra caja? Solo tengo opción para 1".
#
# Yusef lo había pedido en la reunión:
#
#   "Ponerle cantidad dos y aquí te pregunta dos veces... acá sería cantidad de
#    paquetes o productos, y aquí **el peso de cada quien**."
#   "Como le importa que son dos, te da esa opción para dos."
#
# Antes las N cajas nacían con el MISMO peso, así que un tracking con una caja
# de 5 lb y otra de 30 se facturaba como dos de 5 — o como dos de 30, según
# cuál hubieran escrito. Las dos están mal.
#
# **Dónde va la pregunta.** El doc había marcado esto como bloqueado porque
# parecía chocar con el modal de F9: la cantidad recién se sabe al apretarlo,
# así que no se pueden pedir N pesos antes. La salida fue pedirlos **en ese
# mismo modal**, que es donde ya se pregunta la cantidad — Yusef revalidó ese
# flujo en la misma reunión ("le voy a poner dos, ahí está una y dos,
# excelente"). Así no se deshace nada de lo aprobado.
class PesoPorCajaTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "cada caja guarda su propio peso" do
    post etiquetar_url, params: {
      paquete: attrs.merge(
        cajas: { "1" => { peso: 5 }, "2" => { peso: 30 }, "3" => { peso: 12.5 } }
      )
    }

    pesos = Paquete.order(:id).last(3).sort_by(&:numero_caja).map { |p| p.peso.to_f }
    assert_equal [ 5.0, 30.0, 12.5 ], pesos
  end

  test "cada caja guarda sus propias medidas" do
    post etiquetar_url, params: {
      paquete: attrs.merge(
        cajas: {
          "1" => { peso: 5, alto: 10, largo: 10, ancho: 10 },
          "2" => { peso: 5, alto: 40, largo: 30, ancho: 20 }
        }
      )
    }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_equal [ 10, 40 ], cajas.map { |c| c.alto.to_i }
    assert_equal [ 10, 30 ], cajas.map { |c| c.largo.to_i }
  end

  test "lo que no se especifica se hereda del formulario" do
    # Si el operario solo corrige el peso de la caja 2, las medidas de las dos
    # siguen siendo las que escribió arriba.
    post etiquetar_url, params: {
      paquete: attrs.merge(alto: 15,
                           cajas: { "1" => { peso: 5 }, "2" => { peso: 30 } })
    }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_equal [ 15, 15 ], cajas.map { |c| c.alto.to_i }
    assert_equal 30.0, cajas.last.peso.to_f
  end

  test "un campo vacio no pisa el del formulario con nil" do
    # Cada fila manda los cuatro campos; los que el operario dejó en blanco no
    # pueden borrar lo que ya estaba arriba.
    post etiquetar_url, params: {
      paquete: attrs.merge(peso: 7, alto: 15,
                           cajas: { "1" => { peso: 5, alto: "" },
                                    "2" => { peso: 30, alto: "" } })
    }

    assert_equal [ 15, 15 ], Paquete.order(:id).last(2).map { |p| p.alto.to_i }
  end

  # PR-C7.17: la cantidad sale de contar las filas, no de un campo.
  #
  # Antes salía de `cantidad_paquetes`, y cuando PR-C7.04 le sacó ese campo a
  # /etiquetar la pantalla dejó de poder dividir un paquete — sin error y sin
  # aviso. Ahora hay una sola fuente, la misma que usa /entrega_personal.
  test "sin filas agregadas se guarda un solo bulto" do
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: { paquete: attrs.merge(peso: 9) }
    end

    assert_equal 9.0, Paquete.order(:id).last.peso.to_f
  end

  test "cantidad_paquetes ya no decide cuantas cajas se crean" do
    assert_difference "Paquete.count", 2 do
      post etiquetar_url, params: {
        paquete: attrs.merge(cantidad_paquetes: 7,
                             cajas: { "1" => { peso: 5 }, "2" => { peso: 30 } })
      }
    end
  end

  test "una sola fila agregada guarda un bulto con los datos de esa fila" do
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: {
        paquete: attrs.merge(peso: 9, cajas: { "1" => { peso: 22, alto: 3 } })
      }
    end

    creado = Paquete.order(:id).last
    assert_equal 22.0, creado.peso.to_f, "se guardo el peso del formulario, no el de la caja"
    assert_equal 3, creado.alto.to_i
  end

  test "solo se aceptan peso y medidas, no cualquier campo" do
    # El resto del paquete es el mismo para todas las cajas: mismo tracking,
    # mismo cliente, mismo contenido. Lo único que cambia físicamente es
    # cuánto pesa y mide cada bulto.
    post etiquetar_url, params: {
      paquete: attrs.merge(
        cajas: { "1" => { peso: 5 },
                 "2" => { peso: 30, descripcion: "otra cosa", estado: "entregado" } }
      )
    }

    caja2 = Paquete.order(:id).last(2).max_by(&:numero_caja)
    assert_equal 30.0, caja2.peso.to_f
    assert_equal "Paquete de prueba", caja2.descripcion
    assert_equal "recibido_miami", caja2.estado
  end

  test "el peso volumetrico se calcula por caja" do
    # Es derivado de las medidas, así que si las medidas son propias el
    # volumétrico también tiene que serlo — de ahí sale el peso a cobrar.
    post etiquetar_url, params: {
      paquete: attrs.merge(
        cajas: {
          "1" => { peso: 5, alto: 10, largo: 10, ancho: 10 },
          "2" => { peso: 5, alto: 40, largo: 40, ancho: 40 }
        }
      )
    }

    cajas = Paquete.order(:id).last(2).sort_by(&:numero_caja)
    assert_operator cajas.last.peso_volumetrico.to_f, :>, cajas.first.peso_volumetrico.to_f,
                    "la caja grande tendría que tener más peso volumétrico"
  end

  private

  def attrs
    {
      tracking: "CAJA#{SecureRandom.hex(4)}",
      cliente_id: clientes(:juan).id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
