require "test_helper"

# PR-D1.e: tests del 2do tracking — búsqueda + vinculación PA.
class PaqueteTrackingSecundarioTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @sucursal = sucursales(:miami)
  end

  test "Paquete acepta tracking_secundario nullable" do
    p = Paquete.create!(tracking: "1Z999PRINCIPALA", tracking_secundario: "AZ123ALTA",
                        cliente: @cliente, sucursal: @sucursal)
    assert_equal "AZ123ALTA", p.tracking_secundario
  end

  test "buscar scope encuentra por tracking_secundario" do
    Paquete.create!(tracking: "1Z999PRIMARYB", tracking_secundario: "AMZ456ALTB",
                    cliente: @cliente, sucursal: @sucursal)

    assert Paquete.buscar("AMZ456").any?
    assert Paquete.buscar("AMZ456ALTB").any?
  end

  test "buscar también encuentra por tracking primario (regression check)" do
    Paquete.create!(tracking: "1Z999PRIMARYC", cliente: @cliente, sucursal: @sucursal)
    assert Paquete.buscar("1Z999PRIMARYC").any?
  end

  test "tracking_secundario nullable cuando no se provee" do
    p = Paquete.create!(tracking: "1Z999PRIMARYD", cliente: @cliente, sucursal: @sucursal)
    assert_nil p.tracking_secundario
  end

  # ── PreAlertaPaquete.link_tracking! con dual matching ──

  test "link_tracking! matchea contra tracking principal del paquete" do
    pa = pre_alertas(:activa)
    PreAlertaPaquete.create!(pre_alerta: pa, tracking: "1Z999LINKA", fecha: Date.current,
                             descripcion: "x")

    paquete = Paquete.create!(tracking: "1Z999LINKA", cliente: @cliente, sucursal: @sucursal)
    count = PreAlertaPaquete.link_tracking!("1Z999LINKA", paquete)
    assert_equal 1, count
  end

  test "link_tracking! matchea contra tracking_secundario del paquete" do
    pa = pre_alertas(:activa)
    # Cliente pre-alerta con el tracking que el proveedor le dio al cliente.
    PreAlertaPaquete.create!(pre_alerta: pa, tracking: "AMZCLIENTTRK", fecha: Date.current,
                             descripcion: "x")

    # El paquete físico llega con OTRO tracking principal, pero el secundario
    # es el que el cliente pre-alerta.
    paquete = Paquete.create!(
      tracking: "1Z999PHYSICALTRK",
      tracking_secundario: "AMZCLIENTTRK",
      cliente: @cliente,
      sucursal: @sucursal
    )

    count = PreAlertaPaquete.link_tracking!(paquete.tracking, paquete)
    assert_equal 1, count, "debió vincular vía tracking_secundario"
  end

  test "link_tracking! ignora cuando ningún tracking coincide" do
    pa = pre_alertas(:activa)
    PreAlertaPaquete.create!(pre_alerta: pa, tracking: "OTROTRK", fecha: Date.current,
                             descripcion: "x")
    paquete = Paquete.create!(tracking: "DISTINTO", cliente: @cliente, sucursal: @sucursal)
    count = PreAlertaPaquete.link_tracking!("DISTINTO", paquete)
    assert_equal 0, count
  end
end
