class EntregaPersonalController < ApplicationController
  # PR-C6.31: el partial de peso y medidas es el mismo que el de /etiquetar,
  # así que las filas por caja también tienen que leerse igual. Antes esta
  # pantalla las pintaba y después las tiraba: todas las cajas nacían con el
  # peso de arriba.
  include MedidasPorCaja
  # El sellado del prepago vive en el concern porque /etiquetar hace lo mismo.
  include PrepagoMiami
  include NotificaRecibido

  before_action :authorize_entrega_personal

  # PR-6: flow separado para paquetes que llegan FÍSICAMENTE al mostrador
  # en Miami (sin tracking del courier). Sistema genera tracking
  # automático EP-YYYY-SUC-PROV-NNNNNN vía Paquete#generate_ep_tracking
  # callback que ya existe (PR-D3.b).

  def new
    @sucursales_recepcion = sucursales_de_recepcion_con_ep
    # La misma preselección que /etiquetar (gemelas): la sucursal del usuario,
    # si no la de recepción por defecto. Antes el select nacía en blanco.
    @paquete = Paquete.new(sucursal_recepcion: Sucursal.recepcion_por_defecto_para(Current.user, entre: @sucursales_recepcion))
    @paquetes_hoy = paquetes_ep_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @proveedores_ep = Proveedor.where(tipo: "entrega_personal").activos.ordered
    @motivos_retencion = MotivoRetencion.activos.ordered
    @motivos_envio_politica = MotivoEnvioPolitica.activos.ordered
    @tarifas_recolecta = TarifaRecolecta.activas.ordered
  end

  # A7-20. La cantidad de cajas **se deriva de las filas**, no de un campo.
  #
  # Antes venía de un `cantidad_paquetes` que el operario tecleaba, y ese
  # desacople ya había costado un bug: en PR-C6.31 el form mandaba el campo dos
  # veces, ganaba el hidden con valor 1, y el operario veía tres filas pero se
  # grababa un solo paquete. Si el número sale de contar las filas, no hay dos
  # fuentes que puedan discrepar.
  def create
    cajas = medidas_por_caja

    case cajas.size
    when 0 then create_single                          # nunca tocó Agregar: un solo bulto
    when 1 then create_single(cajas.values.first)      # una caja agregada: sus datos mandan
    else        create_split(cajas.size)
    end
  end

  private

  def create_single(medidas = {})
    @paquete = Paquete.new(paquete_params.merge(medidas))
    apply_extra_params(@paquete)
    heredar_sucursal_de_retiro(@paquete)
    @paquete.estado = "recibido_miami"
    @paquete.user = Current.user

    if @paquete.save
      respond_saved([ @paquete ])
    else
      render_create_error
    end
  end

  def create_split(total_cajas)
    attrs = con_sucursal_de_retiro(
      paquete_params.except(:cantidad_paquetes, :numero_caja)
    ).merge(
      estado: "recibido_miami",
      user: Current.user
    )
    paquetes = Paquete.crear_split!(attrs: attrs, total_cajas: total_cajas,
                                    por_caja: medidas_por_caja)
    paquetes.each do |p|
      apply_extra_params(p)
      heredar_sucursal_de_retiro(p)
      p.save!
    end
    respond_saved(paquetes)
  rescue ActiveRecord::RecordInvalid => e
    @paquete = e.record
    render_create_error
  end

  # PR-C6.37: donde retira el cliente. Ojo con el choque de nombres: en esta
  # pantalla `sucursal_id` es la de MIAMI donde se recibe (define el prefijo del
  # tracking EP), asi que la de retiro solo se pone si el form no mando una.
  def heredar_sucursal_de_retiro(paquete)
    paquete.sucursal ||= paquete.cliente&.sucursal_retiro
  end

  # `crear_split!` crea las cajas de una, así que la herencia de la sucursal de
  # retiro tiene que estar puesta **antes** — si no, la primera caja se valida
  # con el campo vacío. Por eso viaja en `attrs` y no solo en el `each` de
  # después.
  def con_sucursal_de_retiro(attrs)
    return attrs if attrs[:sucursal_id].present?

    retiro = Cliente.find_by(id: attrs[:cliente_id])&.sucursal_retiro
    retiro ? attrs.merge(sucursal_id: retiro.id) : attrs
  end

  # `prepagado_miami` se traduce a cinco columnas, así que no puede ir en
  # `paquete_params`. El sellado lo hace `PrepagoMiami`, compartido con
  # /etiquetar: escrito acá otra vez, las dos pantallas se separan.
  def apply_extra_params(paquete, save: false)
    if (prov_str = proveedor_string_param) != :missing
      paquete[:proveedor] = prov_str
    end
    aplicar_prepago_miami(paquete)
    paquete.save! if save
  end

  # C17-02: acá **no** se llama a `Tarea.atar_al_paquete!`, a propósito. El
  # tracking de una entrega personal se genera al guardar (EP-AÑO-SUC-PROV-N),
  # así que la tarea que se deja desde la franja no tiene tracking y no hay por
  # dónde atarla; «la última que dejó este usuario» falla apenas se intercalan
  # dos tareas o dos paquetes. Queda del cliente y sale en la bandeja.
  def respond_saved(paquetes)
    @paquete = paquetes.first
    # C18-06: en Entrega Personal no hay pre-alerta; el correo sale solo si se
    # marcó «enviado según política».
    notificar_recibido(@paquete, pre_alerta_vinculada: false)
    msg = paquetes.size > 1 ?
            "Entrega personal registrada — #{paquetes.size} cajas, tracking #{@paquete.tracking}" :
            "Entrega personal registrada — tracking #{@paquete.tracking}"

    respond_to do |format|
      format.turbo_stream do
        # PR-C7.16: **solo la primera caja dispara la impresión.** Las N cajas de
        # un split comparten tracking desde `crear_split!`, así que
        # `etiqueta?hermanas=1` ya saca las N etiquetas en un solo trabajo.
        # Marcar las tres abría tres ventanas imprimiendo lo mismo tres veces.
        #
        # Yusef: "aquí debería crear las etiquetas para 3 cajas y luego tirar
        # preview del WR" — el WR es uno solo, "al contrario" de la etiqueta.
        events = paquetes.each_with_index.map do |p, i|
          imprime = i.zero? && params[:print].to_s == "true"
          "<div data-entrega-personal-target='event' data-action='paquete-saved' " \
            "data-guia='#{p.guia}' data-print='#{imprime}' data-paquete-id='#{p.id}'></div>"
        end.join
        render turbo_stream: [
          turbo_stream.update("paquetes-counter", paquetes_ep_hoy_count.to_s),
          turbo_stream.prepend("flash-messages", partial: "shared/flash",
                                                 locals: { notice: aviso_con_wr(msg) }),
          turbo_stream.append("entrega-personal-events", events)
        ]
      end
      format.html do
        redirect_to new_entrega_personal_path, notice: msg
      end
    end
  end

  # El aviso lleva el link al Warehouse Receipt.
  #
  # Yusef: *"aquí debería crear las etiquetas para 3 cajas y **luego tirar
  # preview del WR**"*. El JS lo intenta abrir en una ventana, pero Chrome
  # permite **un solo popup por gesto del usuario** y ese ya se lo lleva la
  # ventana de impresión de las etiquetas — que es la que no puede faltar.
  #
  # Así que el WR va también acá, donde no depende del permiso de popups. El
  # texto se escapa; solo el link es HTML.
  def aviso_con_wr(msg)
    return msg if @paquete.nil?

    helpers.safe_join([
      msg,
      " · ",
      helpers.link_to("Ver Warehouse Receipt",
                      warehouse_receipt_paquete_path(@paquete),
                      target: "_blank", rel: "noopener",
                      class: "underline font-medium")
    ])
  end

  # C18-02: las mismas que ofrece /etiquetar (`Sucursal.de_recepcion`), y de
  # ellas las que tienen código EP —sin él no se genera el tracking
  # EP-AÑO-SUC-…—. Acá decía `where(ubicacion: "miami")` a mano: la gemela
  # separada, y México (`otros`) tampoco habría salido.
  def sucursales_de_recepcion_con_ep
    Sucursal.de_recepcion.con_codigo_ep
  end

  def render_create_error
    @paquetes_hoy = paquetes_ep_hoy_count
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @proveedores_ep = Proveedor.where(tipo: "entrega_personal").activos.ordered
    # PR-9.b: faltaba esto — la vista hace `.any?` sobre él, así que cualquier
    # error de validación reventaba con un 500 en vez de mostrar los errores.
    @sucursales_recepcion = sucursales_de_recepcion_con_ep
    @motivos_retencion = MotivoRetencion.activos.ordered
    @motivos_envio_politica = MotivoEnvioPolitica.activos.ordered
    @tarifas_recolecta = TarifaRecolecta.activas.ordered
    # Igual que en /etiquetar: las cajas medidas vuelven a la pantalla. Sin
    # esto, un error de validación las borraba todas.
    @cajas_cargadas = medidas_por_caja
    flash.now[:alert] = "No se pudo registrar la entrega personal."
    render :new, status: :unprocessable_entity
  end

  def authorize_entrega_personal
    require_role(:supervisor_miami, :digitador_miami)
  end

  def paquetes_ep_hoy_count
    Paquete
      .joins(:proveedor)
      .where(proveedores: { tipo: "entrega_personal" })
      .where(user: Current.user)
      .where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
      .count
  end

  def paquete_params
    params.require(:paquete).permit(
      # PR-C7.16: la sucursal de Miami entra como `sucursal_recepcion_id`.
      # `sucursal_id` sigue permitido porque es **dónde retira el cliente**, y el
      # form podría llegar a ofrecerlo; hoy lo hereda `heredar_sucursal_de_retiro`.
      :cliente_id, :tipo_envio_id, :proveedor_id, :sucursal_id, :sucursal_recepcion_id, :peso,
      :alto, :largo, :ancho, :cantidad_productos, :cantidad_paquetes,
      :numero_caja, :descripcion, :remitente, :driver,
      :notas_internas, :notas_retencion,
      :retener_miami, :enviado_por_politica, :notas_envio_politica,
      # A7-22/A7-23: la recolecta vive en esta misma pantalla.
      :recolecta_solicitada, :tarifa_recolecta_id, :recolecta_monto, :recolecta_moneda,
      :recolecta_contacto, :recolecta_telefono, :recolecta_horario, :recolecta_instrucciones,
      :recolecta_direccion,
      motivo_retencion_ids: [], motivo_envio_politica_ids: []
    )
  end

  # `proveedor` string legacy choca con `belongs_to :proveedor` (mismo
  # patrón del bug PR fix #185 en EtiquetarController). Lo extraemos
  # aparte para asignar vía column accessor.
  def proveedor_string_param
    return :missing unless params.dig(:paquete)&.key?(:proveedor)

    params[:paquete][:proveedor].to_s
  end
end
