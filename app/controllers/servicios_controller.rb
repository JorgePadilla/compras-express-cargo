# PR-10.a: la "tabla de servicios" que Yusef pidió — el CRUD que hasta ahora
# no existía. Los precios de `tipo_envios` se habían sembrado a mano:
#
#   "No tenés todavía la tabla de servicio. Creo que las puse a mano."
#   "TODOS ESTOS PRECIOS DEBEN PODER CAMBIAR."   — Yusef, 2026-08-02
#
# Se llama /servicios y no /tarifas porque para el negocio la unidad mental es
# el servicio (EXPRESS, CER, CEM…) y las tarifas son sus filas.
class ServiciosController < ApplicationController
  before_action :require_admin
  before_action :set_tarifa, only: %i[edit update destroy]

  def index
    @tipo_envios = TipoEnvio.activos.order(:nombre)
    @tarifas = Tarifa.includes(:tipo_envio, :categoria_precio, :cliente, :sucursal, :proveedor)
                     .to_a
                     .sort_by { |t| orden_de_lectura(t) }
                     .group_by(&:tipo_envio_id)

    # PR-C7.12: los grupos de clientes se administran acá desde que la pantalla
    # aparte se fue. `count` en vez de `includes` porque lo único que muestra la
    # sección son los dos números, y traerse las filas para contarlas sería
    # cargar las 44 tarifas dos veces.
    @grupos          = CategoriaPrecio.order(:nombre).to_a
    @clientes_por_grupo = Cliente.where.not(categoria_precio_id: nil).group(:categoria_precio_id).count
    @tarifas_por_grupo  = Tarifa.where.not(categoria_precio_id: nil).group(:categoria_precio_id).count
  end

  def new
    @tarifa = Tarifa.new(activo: true, moneda: "USD", desde_libras: 0,
                         aplica_minimo: true, tipo_envio_id: params[:tipo_envio_id])
    cargar_catalogos
  end

  def create
    @tarifa = Tarifa.new(tarifa_params)
    aplicar_minimo_con_isv

    if guardar_con_categoria
      redirect_to servicios_path, notice: "Tarifa creada."
    else
      cargar_catalogos
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    cargar_catalogos
  end

  def update
    @tarifa.assign_attributes(tarifa_params)
    aplicar_minimo_con_isv

    if guardar_con_categoria
      redirect_to servicios_path, notice: "Tarifa actualizada."
    else
      cargar_catalogos
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tarifa.destroy
    redirect_to servicios_path, notice: "Tarifa eliminada."
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  # PR-10.g: con los precios reales cargados esto pasó de 20 filas a ~60, y el
  # orden por id dejaba el precio de lista hasta abajo (en Postgres los NULL
  # ordenan al final). Se lee como una tabla de precios: primero el público,
  # después las excepciones, y dentro de cada una los escalones por peso con
  # la fila general antes que la de sucursal.
  def orden_de_lectura(t)
    nivel = if t.cliente_id          then 3
    elsif t.proveedor_id             then 2
    elsif t.categoria_precio_id      then 1
    else                                  0
    end

    # `downcase` para que "doTERRA" no caiga después de "VIP".
    [ nivel, t.categoria_precio&.nombre.to_s.downcase, t.desde_libras.to_f,
      t.sucursal&.nombre.to_s ]
  end

  def set_tarifa
    @tarifa = Tarifa.find(params[:id])
  end

  # PR-C7.12: el formulario manda el **nombre** de la categoría, y si no existe se
  # crea. Desde que la pantalla aparte se fue, esta es la única forma de crear un
  # grupo — y es donde se necesita, porque uno crea el grupo justo cuando le va a
  # poner precio.
  #
  # Va en una transacción a propósito: si la tarifa no pasa validación, la
  # categoría recién tecleada **no se queda huérfana**. `transaction` devuelve nil
  # cuando se hace rollback, así que sirve tal cual como "¿se guardó?".
  def guardar_con_categoria
    ActiveRecord::Base.transaction do
      asignar_categoria_por_nombre
      @tarifa.save || raise(ActiveRecord::Rollback)
    end
  end

  # Sin el `key?` no se puede distinguir "no mandó el campo" de "lo dejó vacío", y
  # la segunda tiene que poder **quitarle** la categoría a una tarifa.
  def asignar_categoria_por_nombre
    return unless params[:tarifa]&.key?(:categoria_nombre)

    nombre = params[:tarifa][:categoria_nombre].to_s.strip
    @tarifa.categoria_nombre = nombre
    @tarifa.categoria_precio =
      nombre.presence && (CategoriaPrecio.find_by("LOWER(nombre) = ?", nombre.downcase) ||
                          CategoriaPrecio.create!(nombre: nombre))
  end

  def cargar_catalogos
    @tipo_envios       = TipoEnvio.activos.order(:nombre)
    @categorias        = CategoriaPrecio.order(:nombre)
    @sucursales        = Sucursal.activas.ordered
    @proveedores       = Proveedor.activos.ordered
  end

  # Yusef razona en montos CON ISV ("el mínimo es 200 lempiras ya con ISV"),
  # pero la columna guarda el neto para no chocar con el ISV que se aplica al
  # totalizar. El form pregunta por el monto con impuesto y acá se convierte.
  def aplicar_minimo_con_isv
    return unless params[:tarifa].key?(:minimo_monto_con_isv)

    @tarifa.minimo_monto_con_isv = params[:tarifa][:minimo_monto_con_isv]
  end

  def tarifa_params
    params.require(:tarifa).permit(
      # `categoria_nombre` no es una columna: es el nombre tecleado en el campo
      # de grupo, que `asignar_categoria_por_nombre` resuelve a `categoria_precio_id`.
      # Va permitido para que no ensucie el log con "Unpermitted parameter" en
      # cada guardado; el `attr_writer` de `Tarifa` lo absorbe sin tocar la base.
      :tipo_envio_id, :categoria_precio_id, :categoria_nombre,
      :cliente_id, :sucursal_id, :proveedor_id,
      :desde_libras, :hasta_libras, :precio_libra, :moneda,
      :minimo_moneda, :minimo_libras, :aplica_minimo,
      # `incremento_libras` NO se permite: el redondeo a media libra es la regla,
      # no una opcion del formulario. La columna tiene default 0.5 y NOT NULL.
      :activo, :notas
    )
  end
end
