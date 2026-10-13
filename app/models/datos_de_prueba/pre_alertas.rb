# Pre-alertas de prueba, una por paquete, y —si se pide— recibidas en Miami.
#
# Es lo que Jorge hizo a mano en la consola de Render el 2026-10-13 para
# escanear diez paquetes en `MMIA2026000029`, convertido en pantalla. Por qué
# existe y dónde, en `DatosDePrueba`.
#
# - **Sin recibir**: queda la pre-alerta con su paquete esperado
#   (`pre_alerta_estado`). Sirve para probar `/etiquetar`: se escanea el tracking.
# - **Recibida en Miami**: el esperado pasa a `recibido_miami` como lo pasa
#   `EtiquetarController#create_single`, con número de recepción, sucursal de
#   recepción y la de retiro. Con más de un volumen va por `Paquete.crear_split!`
#   reusando el esperado como Caja 1, igual que `create_split`: N cajas con el
#   mismo número madre y el mismo tracking.
class DatosDePrueba::PreAlertas
  Fila = Struct.new(:pre_alerta, :paquetes, keyword_init: true)

  attr_reader :lote, :errores

  def initialize(tipo_envio:, sucursal_retiro:, cantidad:, volumenes: 1, recibir: true,
                 cliente: nil, user: nil)
    @tipo_envio      = tipo_envio
    @sucursal_retiro = sucursal_retiro
    @cantidad        = DatosDePrueba.entero(cantidad, minimo: 1, maximo: DatosDePrueba::MAX_PRE_ALERTAS)
    @volumenes       = DatosDePrueba.entero(volumenes, minimo: 1, maximo: DatosDePrueba::MAX_VOLUMENES)
    @recibir         = recibir
    @cliente         = cliente
    @user            = user
    # Segundos incluidos: dos lotes en el mismo minuto no chocan de tracking.
    @lote            = Time.zone.now.strftime("%m%d%H%M%S")
    @errores         = []
  end

  # Devuelve las filas creadas, o `nil` con `errores` si no se pudo. Todo o
  # nada: un lote a medias deja trackings que nadie sabe de dónde salieron.
  def crear
    return falla("Elegí un tipo de envío.") unless @tipo_envio
    return falla("Elegí la sucursal donde retiran.") unless @sucursal_retiro
    if @volumenes > 1 && !@recibir
      return falla("Los volúmenes se arman al recibir en Miami: marcá «Recibir en Miami».")
    end
    recepcion = Sucursal.recepcion_por_defecto_para(@user)
    return falla("No hay ninguna sucursal que reciba carga (/sucursales).") if @recibir && recepcion.nil?

    cliente = @cliente || DatosDePrueba.cliente_de_prueba(@sucursal_retiro)
    ActiveRecord::Base.transaction do
      (1..@cantidad).map { |i| crear_una(i, cliente, recepcion) }
    end
  rescue ActiveRecord::RecordInvalid => e
    falla("#{e.record.class.model_name.human}: #{e.record.errors.full_messages.to_sentence}")
  end

  private

  def crear_una(i, cliente, recepcion)
    tracking = "#{DatosDePrueba::PREFIJO}#{@lote}#{format('%02d', i)}"
    pre_alerta = PreAlerta.create!(
      cliente: cliente, tipo_envio: @tipo_envio, creado_por_tipo: "usuario",
      titulo: "Prueba #{@lote} · #{i} de #{@cantidad}",
      pre_alerta_paquetes_attributes: [ { tracking: tracking, descripcion: "Mercadería de prueba" } ]
    )
    esperado = pre_alerta.pre_alerta_paquetes.first.paquete
    paquetes = @recibir ? recibir_en_miami(esperado, recepcion, i) : [ esperado ]
    Fila.new(pre_alerta: pre_alerta, paquetes: paquetes)
  end

  def recibir_en_miami(esperado, recepcion, i)
    attrs = {
      estado: "recibido_miami", user: @user, tipo_envio_id: @tipo_envio.id,
      sucursal_recepcion: recepcion, sucursal: @sucursal_retiro,
      tracking: esperado.tracking, cliente_id: esperado.cliente_id,
      descripcion: esperado.descripcion,
      # C30-03: lo que se recibe lleva contenido, como en `/etiquetar`.
      contenido_en_etiquetar: :al_recibir,
      # Medidas que varían un poco, para que el volumétrico no salga igual en todos.
      peso: 4 + i, largo: 12 + i % 5, ancho: 10, alto: 8
    }
    return Paquete.crear_split!(attrs: attrs, total_cajas: @volumenes, reusar: esperado) if @volumenes > 1

    esperado.assign_attributes(attrs)
    esperado.save!
    [ esperado ]
  end

  def falla(mensaje)
    @errores << mensaje
    nil
  end
end
