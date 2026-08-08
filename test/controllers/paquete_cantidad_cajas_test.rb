require "test_helper"

# PR-C6.7: el ajuste de cajas desde `/paquetes`, que es donde Yusef lo vio.
#
# Editó un split de 3 a 2 y quedaron las 3. Después lo subió a 5 y quedaron
# los registros viejos mezclados con los nuevos.
class PaqueteCantidadCajasTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cajas = crear_split(3)
  end

  test "bajar la cantidad desde el form elimina las sobrantes" do
    patch paquete_url(@cajas.first), params: { paquete: { cantidad_paquetes: 2 } }

    assert_redirected_to paquete_path(@cajas.first)
    assert_equal 2, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count
  end

  test "subir la cantidad crea las que faltan" do
    patch paquete_url(@cajas.first), params: { paquete: { cantidad_paquetes: 5 } }

    cajas = Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).order(:numero_caja)
    assert_equal [ 1, 2, 3, 4, 5 ], cajas.map(&:numero_caja)
    assert_equal [ 5 ], cajas.map(&:cantidad_paquetes).uniq
  end

  test "si una caja a eliminar ya se facturo, avisa y no borra nada" do
    @cajas.last.update_columns(estado: "facturado")

    patch paquete_url(@cajas.first), params: { paquete: { cantidad_paquetes: 2 } }

    assert_response :unprocessable_entity
    assert_equal 3, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count,
                 "borró cajas a pesar del bloqueo"
    assert_match(/caja 3/, flash[:alert].to_s)
  end

  test "editar otra cosa no toca las cajas" do
    # El guard de no meterse donde nadie pidió: un update normal que ni
    # menciona la cantidad tiene que dejar el split como está.
    patch paquete_url(@cajas.first), params: { paquete: { descripcion: "otra cosa" } }

    assert_equal 3, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count
    assert_equal "otra cosa", @cajas.first.reload.descripcion
  end

  test "un paquete suelto no entra al ajuste" do
    suelto = Paquete.create!(
      tracking: "SUELTO#{SecureRandom.hex(3)}",
      cliente: clientes(:juan), sucursal_recepcion: sucursales(:miami),
      estado: "empacado", descripcion: "x", user: users(:digitador)
    )

    patch paquete_url(suelto), params: { paquete: { descripcion: "editado" } }

    assert_redirected_to paquete_path(suelto)
    assert_equal "editado", suelto.reload.descripcion
  end

  private

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "CTRL#{SecureRandom.hex(4)}",
        cliente: clientes(:juan),
        sucursal_recepcion: sucursales(:miami),
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end
end
