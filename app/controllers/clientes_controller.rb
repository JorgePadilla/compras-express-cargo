class ClientesController < ApplicationController
  before_action :set_cliente, only: [ :show, :edit, :update ]
  before_action :authorize_buscar, only: [ :buscar ]

  def index
    @clientes = Cliente.activos.includes(:categoria_precio, :sucursal_retiro).order(created_at: :desc)
    @clientes = @clientes.buscar(params[:q]) if params[:q].present?
    @clientes = @clientes.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    cargar_catalogos
    @cliente = Cliente.new
  end

  def create
    @cliente = Cliente.new(cliente_params)
    if @cliente.save
      redirect_to @cliente, notice: "Cliente creado exitosamente."
    else
      cargar_catalogos
      render :new, status: :unprocessable_entity
    end
  end

  def buscar
    # PR-10.f: `buscar_flexible` y no `buscar` — este es el autocomplete que
    # usa el operario con la etiqueta rota en la mano, así que prioriza
    # encontrar algo por encima de la precisión. El filtro del listado
    # (#index) se queda con la estricta.
    clientes = Cliente.activos.buscar_flexible(params[:q])
                      .includes(:categoria_precio, :cliente_cobro_volumetricos).limit(10)
    render json: clientes.map { |c|
      {
        id: c.id,
        codigo: ERB::Util.html_escape(c.codigo),
        nombre: ERB::Util.html_escape(c.nombre_completo),
        notas_miami: ERB::Util.html_escape(c.notas_miami.to_s),
        categoria_precio: ERB::Util.html_escape(c.categoria_precio&.nombre.to_s),
        # PR-C6.24: dónde va a retirar. Miami lo necesita apenas elige el
        # cliente, para separar la caja en la bolsa de esa sucursal. Yusef:
        # "que le salga en rojo 'se entregará en Tegucigalpa'".
        #
        # Ojo: hoy esto es la **ciudad del cliente**, texto libre — es lo mismo
        # que termina imprimiendo la etiqueta en `RETIRA EN`. No hay sucursal
        # de retiro estructurada, así que el aviso es tan confiable como ese
        # texto. Queda como pregunta para Yusef.
        sucursal_retiro: ERB::Util.html_escape(c.sucursal_retiro_nombre.to_s),
        # PR-C6.41: en qué servicios se le cobra solo el volumétrico. Viaja la
        # lista entera y no un booleano porque el tipo de envío puede cambiar
        # después de elegir al cliente (en /entrega_personal es un select), y
        # así la respuesta no depende de cuál estaba seleccionado al buscar.
        solo_volumetrico_en: c.tipo_envio_solo_volumetrico_ids
      }
    }
  end

  def edit
    cargar_catalogos
  end

  def update
    if @cliente.update(cliente_params)
      redirect_to @cliente, notice: "Cliente actualizado exitosamente."
    else
      cargar_catalogos
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Todo lo que el form necesita para pintarse. Va en un método —y no suelto en
  # `new`/`edit`— porque `create`/`update` re-renderizan ese mismo form cuando
  # falla una validación, sin pasar por esas acciones. Olvidar uno de los cuatro
  # caminos revienta la pantalla justo cuando el usuario ya se equivocó, que es
  # el peor momento. Hay un test por camino.
  def cargar_catalogos
    # PR-C6.37: las sucursales donde un cliente puede retirar. Las de Miami no
    # entran: nadie retira alla, es donde se recibe.
    @sucursales_retiro = Sucursal.activas.where.not(ubicacion: "miami").ordered
    # PR-C6.41: los servicios donde se le puede cobrar solo el volumétrico.
    @tipo_envios = TipoEnvio.activos.order(:nombre)
  end

  def set_cliente
    @cliente = Cliente.find(params[:id])
  end

  def authorize_buscar
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def cliente_params
    params.require(:cliente).permit(
      :codigo, :nombre, :apellido, :identidad, :email,
      :telefono, :telefono_whatsapp, :direccion, :ciudad, :sucursal_retiro_id,
      :departamento, :categoria_precio_id, :activo,
      :notas_miami, :notas_honduras,
      :notas_caja, :notas_sac,
      # PR-C6.41: los servicios donde se le cobra solo el volumétrico. Sin esta
      # línea el form guarda en silencio — los checks no dan error, simplemente
      # no pasa nada.
      tipo_envio_solo_volumetrico_ids: []
    )
  end
end
