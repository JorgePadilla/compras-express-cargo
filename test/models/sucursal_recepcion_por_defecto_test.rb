require "test_helper"

# Seguimiento de C18-02 (2026-08-27). Jorge: *"Miami es el default pero podría
# ser DF México, ¿tenemos cómo ingresarlo?"*. Ingresarla ya se podía; lo que no
# había era una regla para el default que no fuera el orden por nombre —y «DF
# México» ordena antes que «Miami».
class SucursalRecepcionPorDefectoTest < ActiveSupport::TestCase
  setup do
    @miami = sucursales(:miami)
    @mexico = Sucursal.create!(codigo: "DFM", codigo_ep: "SDF", nombre: "DF México", pais: "México",
                               ubicacion: "otros", activo: true, recibe_carga: true)
    @admin = users(:admin)         # honduras, sin sucursal: el caso de Yusef
    @digitador = users(:digitador) # miami
  end

  test "la sucursal del usuario manda, aunque no sea la de por defecto" do
    @digitador.update!(sucursal: @mexico)

    assert_equal @mexico, Sucursal.recepcion_por_defecto_para(@digitador)
  end

  test "si la del usuario no recibe carga, manda la marcada por defecto" do
    @admin.update!(sucursal: sucursales(:zeron_sps))

    assert_equal @miami, Sucursal.recepcion_por_defecto_para(@admin)
  end

  test "sin sucursal asignada manda la marcada por defecto, no la primera por nombre" do
    assert_equal "DF México", Sucursal.de_recepcion.first.nombre, "el orden por nombre pone a México primero: eso es lo que no puede decidir"

    assert_equal @miami, Sucursal.recepcion_por_defecto_para(@admin)
  end

  test "sin ninguna marcada, manda la de la ubicacion del usuario" do
    @miami.update!(recepcion_por_defecto: false)

    assert_equal @miami, Sucursal.recepcion_por_defecto_para(@digitador)
  end

  test "sin nada que coincida, la primera; sin sucursales, nil; sin usuario tambien resuelve" do
    @miami.update!(recepcion_por_defecto: false)

    assert_equal @mexico, Sucursal.recepcion_por_defecto_para(@admin)
    assert_nil Sucursal.recepcion_por_defecto_para(@admin, entre: [])
    assert_equal @miami, Sucursal.recepcion_por_defecto_para(nil, entre: [ @miami ])
  end

  test "marcar una como recepcion por defecto desmarca la otra, y eso queda en el audit log" do
    assert_difference -> { @miami.versions.count }, 1 do
      @mexico.update!(recepcion_por_defecto: true)
    end

    assert_not @miami.reload.recepcion_por_defecto?
    assert_equal [ @mexico ], Sucursal.where(recepcion_por_defecto: true).to_a
  end

  test "las de retiro no incluyen ni a Miami ni a una que reciba carga" do
    retiro = Sucursal.de_retiro.to_a

    assert_not_includes retiro, @miami
    assert_not_includes retiro, @mexico
    assert_includes retiro, sucursales(:zeron_sps)
  end

  test "una sucursal se crea sin prefijo de recepcion; si lo trae, sigue validando" do
    assert_nil @mexico.codigo_recepcion_prefix
    assert Sucursal.new(codigo: "PTY", nombre: "Panamá", codigo_recepcion_prefix: "rm1").invalid?
    assert Sucursal.new(codigo: "PTY", nombre: "Panamá", codigo_recepcion_prefix: "  ").valid?
  end
end
