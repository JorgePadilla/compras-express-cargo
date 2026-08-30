require "test_helper"

# C20-11. Jorge, 2026-08-29, con los logs de staging en la mano:
#
#   > "En etiquetar —y probablemente entrega personal— al actualizar varias
#   >  veces da error, cuando actualizamos el número de etiquetas a más y más."
#
# La secuencia exacta de los logs: 3 → 5 pasaba, 5 → 4 pasaba, 4 → 7 era un
# 500 (`AssociationTypeMismatch: Proveedor expected, got ""`). El update
# escribe "" en la columna legacy `proveedor` de la caja que edita —o de la
# caja 1, si se reancló al bajar— y la siguiente subida copiaba ese "" por
# `create!`, que para `proveedor` es el writer de la asociación.
#
# Entrega Personal no tiene update de cajas (solo crea, y `crear_split!` va por
# otro camino), así que no le pega. Pero un paquete EP re-escaneado en
# /etiquetar, y la edición en /paquetes, sí pasan por `ajustar_split!`.
class EtiquetarActualizarVariasVecesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
  end

  test "subir, bajar y volver a subir las cajas con el proveedor vacío en el formulario" do
    paquete = crear_recibido

    actualizar(paquete, cajas: 3)
    assert_equal 3, cajas_de(paquete).size

    # Bajar editando la más nueva: se borra, y el formulario se reancla a la
    # caja 1 y le escribe lo que traía — "" incluido.
    actualizar(cajas_de(paquete).last, cajas: 2)
    assert_equal [ 1, 2 ], cajas_de(paquete).map(&:numero_caja)

    # Acá era el 500.
    actualizar(cajas_de(paquete).last, cajas: 5)
    assert_equal [ 1, 2, 3, 4, 5 ], cajas_de(paquete).map(&:numero_caja)
    assert_equal [ 5 ] * 5, cajas_de(paquete).map(&:cantidad_paquetes)
  end

  test "con un proveedor tipeado al recibir, la primera subida ya reventaba" do
    paquete = crear_recibido
    paquete.update_column(:proveedor, "Amazon")  # lo que deja `create` con el campo lleno

    actualizar(paquete, cajas: 3, proveedor: "Amazon")

    assert_equal [ "Amazon" ] * 3, cajas_de(paquete).map { |c| c[:proveedor] },
                 "el origen que sale en la etiqueta tiene que estar en las tres"
  end

  private

  def actualizar(caja, cajas:, proveedor: "")
    patch actualizar_etiquetar_url(caja),
          params: { paquete: { cantidad_paquetes: cajas, proveedor: proveedor } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success, "caja #{caja.numero_caja || 1} → #{cajas} cajas no fue 200"
  end

  def cajas_de(paquete)
    Paquete.where(tracking: paquete.tracking).order(:numero_caja).to_a
  end

  def crear_recibido
    Paquete.create!(
      tracking: "VAR#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
      sucursal_recepcion: @miami, estado: "recibido_miami", descripcion: "Perfumes",
      # Sin peso a propósito: desde C20-12, subir las cajas de un envío pesado
      # exige pesar cada una (`etiquetar_pesar_al_partir_test`). Acá el tema es
      # el proveedor legacy, no el peso.
      peso: nil, user: @user
    )
  end
end
