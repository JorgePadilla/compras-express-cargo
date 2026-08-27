class ClientesController < ApplicationController
  # C16-06 · Yusef, 2026-08-25: *"Miami no va a poder ver todo… vamos a
  # sectorizar las cosas. Aquí van a tener restricciones de ver y de modificar,
  # sobre todo"*. Miami busca clientes —*"llegó un paquete a nombre de Carmen,
  # con el código cortado… empiezan a escribir, a buscar quién aparece"*— pero
  # la ficha es data de Honduras. Hasta acá **nadie** tenía guard: cualquier
  # rol creaba y editaba.
  #
  # Lista positiva, como `PaquetesController::EDIT_ROLES`. Jorge (2026-08-25):
  # solo el digitador queda en consulta; el supervisor de Miami sigue editando.
  # Qué de la ficha **no** debe ver Miami queda en `RP-43`.
  EDICION_ROLES = %w[admin supervisor_miami supervisor_caja supervisor_prefactura
                     cajero sac supervisor_sac entrega_despacho].freeze

  before_action :set_cliente, only: [ :show, :edit, :update, :clave ]
  before_action :authorize_buscar, only: [ :buscar ]
  before_action :authorize_edicion, only: [ :new, :create, :edit, :update, :clave ]

  def index
    base = Cliente.activos.includes(:categoria_precio, :sucursal_retiro)
    # C16-06: la lista buscaba con la estricta y ordenaba por fecha de alta
    # **antes** de buscar, así que «10» traía C10, C100, C210… con C10 hundido
    # donde cayera; el autocomplete de /etiquetar usaba la flexible, que pone el
    # código primero. Yusef probó la lista con «1» y «10» y Jorge: *"ese filtro
    # no lo tengo así como lo querés"*. Una sola búsqueda de cliente
    # (PR-C6.32): la del autocomplete, y la fecha de alta solo desempata.
    @clientes = if params[:q].present?
      base.buscar_flexible(params[:q]).order(created_at: :desc)
    else
      base.order(created_at: :desc)
    end
    @clientes = @clientes.page(params[:page]).per(per_page_sanitized)
  end

  def show
  end

  def new
    # El orden importa: `cargar_catalogos` arma el megacuadro y necesita saber
    # de qué cliente se trata, aunque todavía no exista.
    @cliente = Cliente.new
    cargar_catalogos
  end

  def create
    @cliente = Cliente.new(cliente_params)
    # Acá alguien está **tecleando** el nombre, y es donde Yusef pidió los tres
    # ítems: *"por lo menos tenés que tener Jorge y dos apellidos… imaginate
    # cuántos Jorge Padilla hay"*. El importador de los 9.000 viejos no pasa por
    # esta pantalla y no se entera.
    @cliente.exigir_nombre_completo = true
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
    # encontrar algo por encima de la precisión. Desde C16-06 el listado
    # (#index) busca igual.
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
        # Si retira donde retira casi todo el mundo, el aviso de bolsa no sale.
        # Va acá **y** en `detect_pre_alerta_match`: los dos caminos fijan el
        # cliente en la pantalla, y ya se separaron una vez por olvidar uno.
        retiro_por_defecto: c.retira_en_la_de_por_defecto?,
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

  # PR-C7.15: el megacuadro escribe `tarifas` de nivel cliente, así que guardar
  # el cliente y guardar sus precios es **una sola operación**. Media negociación
  # aplicada —el cliente con su grupo nuevo pero sin el precio que lo acompaña—
  # cobraría mal hasta que alguien se diera cuenta.
  def update
    precios = PreciosEspecialesDelCliente.new(@cliente)

    # Al editar, **solo si están tocando el nombre**. Los 9.000 viejos vienen con
    # dos palabras: abrir uno para corregirle el teléfono no puede trabarse por
    # algo que nadie tocó. Es la misma trampa del método de prepago y la del
    # consolidado.
    @cliente.exigir_nombre_completo = cliente_params.key?(:nombre) || cliente_params.key?(:apellido)

    guardado = ActiveRecord::Base.transaction do
      @cliente.update(cliente_params) &&
        precios.aplicar(params[:precios_especiales]) ||
        raise(ActiveRecord::Rollback)
    end

    if guardado
      redirect_to @cliente, notice: "Cliente actualizado exitosamente."
    else
      flash.now[:alert] = precios.errores.to_sentence if precios.errores.any?
      cargar_catalogos
      render :edit, status: :unprocessable_entity
    end
  end

  # Le pone la clave del portal, o se la cambia si se le olvidó.
  #
  # Yusef, 2026-08-19, señalando la ficha del cliente: *"¿cuál es la cuenta de
  # acceso de él? Eso es todo. Y **cambiarle la clave** por si se le olvidó"*.
  #
  # Hasta acá no existía en ningún lado: `cliente_params` no permite `:password`
  # y `PasswordsController` era solo de `User`, así que **un cliente creado por
  # el admin nacía sin clave y no podía entrar nunca** — le salía "contraseña
  # incorrecta" para siempre, que es justo el problema que él estaba describiendo.
  def clave
    nueva = params.dig(:cliente, :password)

    if nueva.blank?
      return redirect_to @cliente, alert: "Escribí la clave nueva."
    end

    if @cliente.cambiar_clave(nueva, params.dig(:cliente, :password_confirmation))
      redirect_to @cliente, notice: "Clave del portal actualizada."
    else
      redirect_to @cliente, alert: @cliente.errors.full_messages.to_sentence
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
    # entran: nadie retira alla, es donde se recibe. Ni ninguna que reciba
    # carga (una México de prueba aparecía acá — seguimiento de C18-02).
    @sucursales_retiro = Sucursal.de_retiro
    # PR-C6.41: los servicios donde se le puede cobrar solo el volumétrico.
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    # PR-C7.15 · A7-26: el megacuadro. Una fila por servicio, con lo que paga
    # hoy, de dónde sale, y su excepción si tiene. También se arma para un
    # cliente sin guardar: ahí las celdas de precio van deshabilitadas pero el
    # cobro por volumen se puede marcar desde el alta, que es como Yusef lo pidió.
    @filas_de_precios = PreciosEspecialesDelCliente.new(@cliente || Cliente.new).filas(@tipo_envios)
  end

  def set_cliente
    @cliente = Cliente.find(params[:id])
  end

  def authorize_buscar
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  # Redirige a la lista y no a `root_path` como `require_role`: para el
  # digitador el home a su vez redirige a /etiquetar con otro alert, y el
  # mensaje se perdería en la segunda vuelta.
  def authorize_edicion
    return if Current.user&.admin?
    return if EDICION_ROLES.include?(Current.user&.rol)

    redirect_to clientes_path,
                alert: "Tu rol solo consulta clientes. Crear y editar es de Honduras y del supervisor de Miami."
  end

  def cliente_params
    params.require(:cliente).permit(
      :codigo, :nombre, :apellido, :identidad, :rtn, :email,
      # El acceso al portal: se corta sin dar de baja al cliente.
      :acceso_habilitado,
      :telefono, :telefono_whatsapp, :direccion, :ciudad, :sucursal_retiro_id,
      :departamento, :categoria_precio_id, :activo,
      :notas_miami, :notas_honduras,
      :notas_caja, :notas_sac,
      # PR-C6.41: los servicios donde se le cobra solo el volumétrico. Sin esta
      # línea el form guarda en silencio — los checks no dan error, simplemente
      # no pasa nada.
      tipo_envio_solo_volumetrico_ids: [],
      # Los correos a los que además hay que avisarle.
      cliente_correos_attributes: %i[id correo _destroy]
    )
  end
end
