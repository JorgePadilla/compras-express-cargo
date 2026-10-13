# Un manifiesto oficial de prueba, con sus cajas y —si se pide— lleno con los
# paquetes de prueba que están sueltos en Miami. Por qué existe y dónde, en
# `DatosDePrueba`.
#
# Se crea como lo crea el formulario (`ManifiestosController#create`): sale de
# la sucursal que recibe, con número anual, y lleva los tipos de envío y las
# sucursales de entrega que se marcaron (C31-09). El encabezado del proveedor
# —empresa, consignatario, su tipo de envío— toma el primero de cada catálogo,
# para que la ficha y el impreso se vean como los de verdad.
#
# Llenar va por `Manifiesto#empacar!`, la misma puerta de la barra (C31-01):
# cada paquete entra en una caja y queda `empacado`. Solo entran los que la
# pistola dejaría entrar (`EscaneoDeManifiesto#clasificar` → `:ok`). Lo normal
# es **no** llenarlo y escanear a mano, que es lo que se quiere probar.
class DatosDePrueba::ArmarManifiesto
  attr_reader :errores, :metidos

  def initialize(tipo_envio_ids:, sucursal_entrega_ids:, cajas: 1, llenar: false, user: nil)
    @tipo_envio_ids       = Array(tipo_envio_ids).compact_blank
    @sucursal_entrega_ids = Array(sucursal_entrega_ids).compact_blank
    @cajas                = DatosDePrueba.entero(cajas, minimo: 0, maximo: DatosDePrueba::MAX_CAJAS)
    @llenar               = llenar
    @user                 = user
    @errores              = []
    @metidos              = 0
  end

  # El manifiesto creado, o `nil` con `errores`.
  def crear
    manifiesto = nil
    ActiveRecord::Base.transaction do
      manifiesto = Manifiesto.create!(
        tipo: "oficial", user: @user,
        sucursal_origen: Sucursal.recepcion_por_defecto_para(@user),
        tipo_envio_ids: @tipo_envio_ids, sucursal_entrega_ids: @sucursal_entrega_ids,
        empresa_manifiesto: EmpresaManifiesto.activos.order(:nombre).first,
        consignatario: Consignatario.activos.ordered.first,
        tipo_envio_proveedor: TipoEnvioProveedor.activos.ordered.first
      )
      # Con peso: sin peso, el manifiesto no se finaliza (C31-07).
      cajas = Array.new(@cajas) do
        manifiesto.cajas.create!(user: @user, peso: 20, largo: 20, ancho: 20, alto: 20)
      end
      llenar!(manifiesto, cajas) if @llenar
      manifiesto.recalculate_totals!
    end
    manifiesto
  rescue ActiveRecord::RecordInvalid => e
    @errores << e.record.errors.full_messages.to_sentence
    nil
  rescue Manifiesto::NoEntra => e
    @errores << e.message
    nil
  end

  private

  # Repartidos entre las cajas en orden, como si se fueran llenando una por una.
  def llenar!(manifiesto, cajas)
    escaneo = EscaneoDeManifiesto.new(manifiesto)
    sueltos = DatosDePrueba.paquetes.where(estado: "recibido_miami", manifiesto_id: nil)
                           .includes(:manifiesto, :tipo_envio).order(:id)
    sueltos.select { |p| escaneo.clasificar(p).ok? }.each_with_index do |paquete, i|
      manifiesto.empacar!(paquete, user: @user, caja: cajas.any? ? cajas[i % cajas.size] : nil)
      @metidos += 1
    end
  end
end
