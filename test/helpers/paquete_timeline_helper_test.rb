require "test_helper"

# C32-04 · La línea de tiempo del paquete, para buscar en cámara. Yusef: *"en el
# paquete necesitamos qué fecha y hora se prefacturó… y fecha que se midió,
# quién lo midió, quién lo prefacturó, quién lo facturó en caja, quién lo
# entregó… al minuto, segundo, porque es para buscar en cámara"*.
class PaqueteTimelineHelperTest < ActionView::TestCase
  include PaqueteTimelineHelper

  setup do
    @paquete = Paquete.create!(tracking: "1ZLINEATIEMPO01", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                               descripcion: "Zapatos", peso: 2)
  end

  def paso(label) = paquete_timeline_steps(@paquete.reload).find { |s| s[:label] == label }

  test "los pasos nuevos van en el orden del recorrido" do
    labels = paquete_timeline_steps(@paquete).map { |s| s[:label] }

    assert_equal %w[Aduana Medido Pre-facturado Consolidando], labels[labels.index("Aduana"), 4]
    assert_equal [ "Disponible", "Facturado en caja", "En reparto" ], labels[labels.index("Disponible"), 3]
  end

  test "sin medir, ni pre-factura, ni cobro, los tres están pendientes" do
    [ "Medido", "Pre-facturado", "Facturado en caja" ].each do |label|
      assert_nil paso(label)[:fecha], label
    end
  end

  test "Medido: el momento y las iniciales que dejó la PESA" do
    medido = Time.zone.parse("2026-10-14 15:42:07")
    @paquete.update_columns(medido_at: medido, medido_por: "MD")

    assert_equal medido, paso("Medido")[:fecha]
    assert_equal "MD", paso("Medido")[:quien]
  end

  test "Pre-facturado: cuándo entró a la pre-factura y quién la auditó, con el link" do
    pf = PreFactura.create!(cliente: clientes(:juan), numero: "PFLINEA1", estado: "creado",
                            creado_por: users(:admin), auditado_por: users(:supervisor_prefactura))
    item = pf.pre_factura_items.create!(concepto: "Flete", subtotal: 10, paquete: @paquete)
    item.update_columns(created_at: Time.zone.parse("2026-10-14 16:01:30"))
    @paquete.update_columns(pre_factura_id: pf.id)

    assert_equal Time.zone.parse("2026-10-14 16:01:30"), paso("Pre-facturado")[:fecha]
    assert_equal users(:supervisor_prefactura), paso("Pre-facturado")[:user]
    assert_includes paso("Pre-facturado")[:contexto].map(&:second), "PFLINEA1"
  end

  test "Pre-facturado sin auditar: queda quien la creó" do
    pf = PreFactura.create!(cliente: clientes(:juan), numero: "PFLINEA2", estado: "creado", creado_por: users(:admin))
    @paquete.update_columns(pre_factura_id: pf.id)

    assert_equal pf.created_at.to_i, paso("Pre-facturado")[:fecha].to_i
    assert_equal users(:admin), paso("Pre-facturado")[:user]
  end

  test "Facturado en caja: solo cuando la venta quedó cobrada, con quien registró el pago" do
    venta = Venta.create!(cliente: clientes(:juan), numero: "VLINEA1", estado: "pendiente", total: 10,
                          creado_por: users(:admin))
    @paquete.update_columns(venta_id: venta.id)
    assert_nil paso("Facturado en caja")[:fecha], "facturada pero sin cobrar no cuenta"

    cobrada = Time.zone.parse("2026-10-14 17:05:44")
    pago = Pago.new(venta: venta, cliente: clientes(:juan), monto: 10, metodo_pago: Pago::METODOS.first,
                    pagado_at: cobrada, registrado_por: users(:cajero))
    pago.save!(validate: false)
    venta.update_columns(estado: "pagada", pagada_at: cobrada)

    assert_equal cobrada, paso("Facturado en caja")[:fecha]
    assert_equal users(:cajero), paso("Facturado en caja")[:user]
    assert_includes paso("Facturado en caja")[:contexto].map(&:second), "VLINEA1"
  end
end
